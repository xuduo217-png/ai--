import {
  Injectable,
  Logger,
  OnModuleInit,
  BadRequestException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Payment, PaymentMethod } from './entities/payment.entity';
import * as crypto from 'crypto';
import axios from 'axios';
import {
  createBusinessException,
  ErrorCode,
} from '../common/constants/error-codes';

/**
 * 微信支付服务
 * 文档：https://pay.weixin.qq.com/wiki/doc/apiv3/index.shtml
 */
@Injectable()
export class WechatPayService implements OnModuleInit {
  private readonly logger = new Logger(WechatPayService.name);

  // 微信支付配置
  private appId: string;
  private mchId: string;
  private apiKey: string;
  private apiclientKey: string;
  private apiclientCert: string;
  private serialNo: string;
  private apiBase: string;
  private configured = false; // 标记是否已配置

  constructor(private configService: ConfigService) {}

  onModuleInit() {
    // 初始化微信支付配置
    this.appId = this.configService.get('WECHAT_PAY_APP_ID');
    this.mchId = this.configService.get('WECHAT_PAY_MCH_ID');
    this.apiKey = this.configService.get('WECHAT_PAY_API_KEY');
    this.apiclientKey = this.configService.get('WECHAT_PAY_APICLIENT_KEY');
    this.apiclientCert = this.configService.get('WECHAT_PAY_APICLIENT_CERT');
    this.serialNo = this.configService.get('WECHAT_PAY_SERIAL_NO');
    this.apiBase =
      this.configService.get('WECHAT_PAY_API_BASE') ||
      'https://api.mch.weixin.qq.com';

    // 如果未配置微信支付,则记录警告(开发环境)
    if (!this.appId || !this.mchId || !this.apiKey) {
      this.logger.warn(
        'Wechat Pay credentials not configured, payment features will be disabled',
      );
      this.configured = false;
      return;
    }

    this.configured = true;
    this.logger.log('Wechat Pay initialized');
  }

  /**
   * 确保微信支付已配置
   * @private
   */
  private ensureConfigured() {
    if (!this.configured) {
      throw createBusinessException(
        ErrorCode.CONFIGURATION_ERROR,
        'Wechat Pay is not configured. Please set WECHAT_PAY_APP_ID, WECHAT_PAY_MCH_ID and WECHAT_PAY_API_KEY in .env',
      );
    }
  }

  /**
   * 创建支付
   */
  async createPayment(payment: Payment): Promise<any> {
    this.ensureConfigured();

    const { paymentNo, outTradeNo, amount, subject, body, method, expiredAt } =
      payment;

    try {
      // 根据支付方式调用不同的接口
      if (method === PaymentMethod.APP) {
        return await this.createAppPayment(payment);
      } else if (method === PaymentMethod.JSAPI) {
        return await this.createJsapiPayment(payment);
      } else if (method === PaymentMethod.H5) {
        return await this.createH5Payment(payment);
      } else if (method === PaymentMethod.NATIVE) {
        return await this.createNativePayment(payment);
      } else {
        throw new BadRequestException(`Unsupported payment method: ${method}`);
      }
    } catch (error) {
      this.logger.error(
        `Create wechat payment failed: ${error.message}`,
        error.stack,
      );
      throw error;
    }
  }

  /**
   * APP 支付
   * 返回支付参数给客户端，客户端使用 SDK 调起支付
   */
  private async createAppPayment(payment: Payment): Promise<any> {
    const { outTradeNo, amount, subject, description, expiredAt } = payment;

    const nonceStr = this.generateNonceStr();
    const timeStamp = Math.floor(Date.now() / 1000).toString();

    // 构建请求参数
    const params = {
      appid: this.appId,
      mchid: this.mchId,
      description: description || subject,
      out_trade_no: outTradeNo,
      notify_url: this.configService.get('WECHAT_PAY_NOTIFY_URL'),
      amount: {
        total: Math.round(amount * 100), // 微信支付金额单位为分
        currency: 'CNY',
      },
      time_expire: this.formatTimeExpire(expiredAt),
    };

    try {
      // 调用微信统一下单接口
      const response = await axios.post(
        `${this.apiBase}/v3/pay/transactions/app`,
        params,
        {
          headers: this.buildSignHeaders(
            'POST',
            '/v3/pay/transactions/app',
            params,
          ),
        },
      );

      const prepayId = this.requireWechatResponseField<string>(
        response.data,
        'prepay_id',
        'APP 支付预下单',
      );

      // 构建客户端支付参数
      const paySign = this.buildAppPaySign(
        this.appId,
        timeStamp,
        nonceStr,
        prepayId,
      );

      this.logger.log(
        `Wechat Pay APP payment created: ${outTradeNo}, amount: ${amount}`,
      );

      return {
        wechatAppid: this.appId,
        wechatPartnerId: this.mchId,
        wechatPrepayId: prepayId,
        wechatNonceStr: nonceStr,
        wechatTimeStamp: timeStamp,
        wechatSign: paySign,
      };
    } catch (error) {
      this.logger.error(
        `Wechat Pay APP payment failed: ${error.message}`,
        error.stack,
      );
      throw error;
    }
  }

  /**
   * JSAPI 支付（公众号/小程序）
   */
  private async createJsapiPayment(payment: Payment): Promise<any> {
    const { outTradeNo, amount, subject, description, expiredAt, metadata } =
      payment;

    if (!metadata?.openid) {
      throw createBusinessException(
        ErrorCode.BUSINESS_INVALID_PARAM,
        'JSAPI payment requires openid in metadata',
      );
    }

    const params = {
      appid: this.appId,
      mchid: this.mchId,
      description: description || subject,
      out_trade_no: outTradeNo,
      notify_url: this.configService.get('WECHAT_PAY_NOTIFY_URL'),
      amount: {
        total: Math.round(amount * 100),
        currency: 'CNY',
      },
      time_expire: this.formatTimeExpire(expiredAt),
      payer: {
        openid: metadata.openid,
      },
    };

    try {
      const response = await axios.post(
        `${this.apiBase}/v3/pay/transactions/jsapi`,
        params,
        {
          headers: this.buildSignHeaders(
            'POST',
            '/v3/pay/transactions/jsapi',
            params,
          ),
        },
      );

      const prepayId = this.requireWechatResponseField<string>(
        response.data,
        'prepay_id',
        'JSAPI 支付预下单',
      );
      const nonceStr = this.generateNonceStr();
      const timeStamp = Math.floor(Date.now() / 1000).toString();
      const paySign = this.buildJsapiPaySign(
        this.appId,
        timeStamp,
        nonceStr,
        prepayId,
      );

      this.logger.log(
        `Wechat Pay JSAPI payment created: ${outTradeNo}, amount: ${amount}`,
      );

      return {
        wechatAppid: this.appId,
        wechatTimeStamp: timeStamp,
        wechatNonceStr: nonceStr,
        wechatPackage: `prepay_id=${prepayId}`,
        wechatSignType: 'RSA',
        wechatPaySign: paySign,
      };
    } catch (error) {
      this.logger.error(
        `Wechat Pay JSAPI payment failed: ${error.message}`,
        error.stack,
      );
      throw error;
    }
  }

  /**
   * H5 支付
   */
  private async createH5Payment(payment: Payment): Promise<any> {
    const { outTradeNo, amount, subject, description, expiredAt, metadata } =
      payment;

    const params = {
      appid: this.appId,
      mchid: this.mchId,
      description: description || subject,
      out_trade_no: outTradeNo,
      notify_url: this.configService.get('WECHAT_PAY_NOTIFY_URL'),
      amount: {
        total: Math.round(amount * 100),
        currency: 'CNY',
      },
      time_expire: this.formatTimeExpire(expiredAt),
      scene_info: {
        payer_client_ip: metadata?.clientIp || '127.0.0.1',
        h5_info: {
          type: 'Wap',
        },
      },
    };

    try {
      const response = await axios.post(
        `${this.apiBase}/v3/pay/transactions/h5`,
        params,
        {
          headers: this.buildSignHeaders(
            'POST',
            '/v3/pay/transactions/h5',
            params,
          ),
        },
      );

      const paymentUrl = this.requireWechatResponseField<string>(
        response.data,
        'h5_url',
        'H5 支付预下单',
      );

      this.logger.log(
        `Wechat Pay H5 payment created: ${outTradeNo}, amount: ${amount}`,
      );

      return {
        paymentUrl,
      };
    } catch (error) {
      this.logger.error(
        `Wechat Pay H5 payment failed: ${error.message}`,
        error.stack,
      );
      throw error;
    }
  }

  /**
   * Native 支付（扫码支付）
   */
  private async createNativePayment(payment: Payment): Promise<any> {
    const { outTradeNo, amount, subject, description, expiredAt } = payment;

    const params = {
      appid: this.appId,
      mchid: this.mchId,
      description: description || subject,
      out_trade_no: outTradeNo,
      notify_url: this.configService.get('WECHAT_PAY_NOTIFY_URL'),
      amount: {
        total: Math.round(amount * 100),
        currency: 'CNY',
      },
      time_expire: this.formatTimeExpire(expiredAt),
    };

    try {
      const response = await axios.post(
        `${this.apiBase}/v3/pay/transactions/native`,
        params,
        {
          headers: this.buildSignHeaders(
            'POST',
            '/v3/pay/transactions/native',
            params,
          ),
        },
      );

      const qrCodeUrl = this.requireWechatResponseField<string>(
        response.data,
        'code_url',
        'Native 支付预下单',
      );

      this.logger.log(
        `Wechat Pay Native payment created: ${outTradeNo}, amount: ${amount}`,
      );

      return {
        qrCodeUrl,
      };
    } catch (error) {
      this.logger.error(
        `Wechat Pay Native payment failed: ${error.message}`,
        error.stack,
      );
      throw error;
    }
  }

  /**
   * 验证回调签名
   */
  async verifyCallback(
    callbackData: any,
    headers?: any,
    rawBody?: string,
  ): Promise<{ valid: boolean; outTradeNo: string; transactionId: string }> {
    this.ensureConfigured();

    try {
      // 微信支付 v3 回调验签
      const timestamp =
        headers?.wechatpaytimestamp || headers?.['wechatpay-timestamp'];
      const nonce = headers?.wechatpaynonce || headers?.['wechatpay-nonce'];
      const signature =
        headers?.wechatpaysignature || headers?.['wechatpay-signature'];
      if (rawBody === undefined) {
        throw new Error('Missing raw callback body');
      }
      const body = rawBody;

      if (!timestamp || !nonce || !signature) {
        this.logger.warn('Wechat Pay callback missing required headers');
        return { valid: false, outTradeNo: null, transactionId: null };
      }

      // 构建待签名串
      const signStr = `${timestamp}\n${nonce}\n${body}\n`;

      // 验证签名
      const isValid = this.verifySignature(signStr, signature);

      if (!isValid) {
        this.logger.warn('Wechat Pay callback signature verification failed');
        return { valid: false, outTradeNo: null, transactionId: null };
      }

      // 解密数据
      const resource = callbackData.resource;
      const decrypted = this.decryptResource(
        resource.ciphertext,
        resource.associated_data,
        resource.nonce,
      );

      const decryptedData = JSON.parse(decrypted);
      const outTradeNo = decryptedData.out_trade_no;
      const transactionId = decryptedData.transaction_id;
      const tradeState = decryptedData.trade_state;

      // 验证交易状态：只有 SUCCESS 状态才视为支付成功
      if (tradeState !== 'SUCCESS') {
        this.logger.warn(
          `Wechat Pay trade state not success: ${outTradeNo}, state: ${tradeState}`,
        );
        return { valid: false, outTradeNo: null, transactionId: null };
      }

      this.logger.log(`Wechat Pay callback verified: ${outTradeNo}`);

      return { valid: true, outTradeNo, transactionId };
    } catch (error) {
      this.logger.error(
        `Verify wechat pay callback failed: ${error.message}`,
        error.stack,
      );
      return { valid: false, outTradeNo: null, transactionId: null };
    }
  }

  /**
   * 查询支付状态
   */
  async queryPayment(payment: Payment): Promise<string> {
    this.ensureConfigured();

    try {
      const response = await axios.get(
        `${this.apiBase}/v3/pay/transactions/out-trade-no/${payment.outTradeNo}`,
        {
          headers: this.buildSignHeaders(
            'GET',
            `/v3/pay/transactions/out-trade-no/${payment.outTradeNo}`,
            {},
          ),
          params: {
            mchid: this.mchId,
          },
        },
      );

      const tradeState = response.data.trade_state;
      this.logger.log(
        `Wechat Pay payment queried: ${payment.outTradeNo}, status: ${tradeState}`,
      );

      return tradeState;
    } catch (error) {
      this.logger.error(
        `Query wechat pay payment failed: ${error.message}`,
        error.stack,
      );
      throw error;
    }
  }

  /**
   * 关闭支付
   */
  async closePayment(payment: Payment): Promise<void> {
    this.ensureConfigured();

    try {
      await axios.post(
        `${this.apiBase}/v3/pay/transactions/out-trade-no/${payment.outTradeNo}/close`,
        {
          mchid: this.mchId,
        },
        {
          headers: this.buildSignHeaders(
            'POST',
            `/v3/pay/transactions/out-trade-no/${payment.outTradeNo}/close`,
            {
              mchid: this.mchId,
            },
          ),
        },
      );

      this.logger.log(`Wechat Pay payment closed: ${payment.outTradeNo}`);
    } catch (error) {
      if (
        axios.isAxiosError(error) &&
        (error.response?.status === 404 ||
          error.response?.data?.code === 'ORDER_NOT_EXIST')
      ) {
        this.logger.log(
          `Wechat payment was not created and needs no close: ${payment.outTradeNo}`,
        );
        return;
      }
      this.logger.error(
        `Close wechat pay payment failed: ${error.message}`,
        error.stack,
      );
      throw error;
    }
  }

  /**
   * 创建退款
   */
  async createRefund(
    payment: Payment,
    refundAmount: number,
    refundNo: string,
    reason: string,
  ): Promise<string> {
    this.ensureConfigured();

    try {
      const params = {
        out_trade_no: payment.outTradeNo,
        out_refund_no: refundNo,
        reason: reason || '正常退款',
        notify_url: this.configService.get('WECHAT_PAY_REFUND_NOTIFY_URL'),
        amount: {
          refund: Math.round(refundAmount * 100),
          total: Math.round(payment.amount * 100),
          currency: 'CNY',
        },
      };

      const response = await axios.post(
        `${this.apiBase}/v3/refund/domestic/refunds`,
        params,
        {
          headers: this.buildSignHeaders(
            'POST',
            '/v3/refund/domestic/refunds',
            params,
          ),
        },
      );

      const refundId = this.requireWechatResponseField<string>(
        response.data,
        'refund_id',
        '退款申请',
        ErrorCode.REFUND_FAILED,
      );

      this.logger.log(
        `Wechat Pay refund created: ${refundNo}, amount: ${refundAmount}`,
      );

      return refundId;
    } catch (error) {
      this.logger.error(
        `Create wechat pay refund failed: ${error.message}`,
        error.stack,
      );
      throw error;
    }
  }

  /**
   * 构建签名头
   */
  private buildSignHeaders(method: string, url: string, body: any): any {
    const timestamp = Math.floor(Date.now() / 1000);
    const nonceStr = this.generateNonceStr();
    const signStr = this.buildSignString(
      method,
      url,
      timestamp,
      nonceStr,
      body,
    );
    const signature = this.sign(signStr);

    return {
      Authorization: `WECHATPAY2-SHA256-RSA2048 mchid="${this.mchId}",serial_no="${this.serialNo}",timestamp="${timestamp}",nonce_str="${nonceStr}",signature="${signature}"`,
      'Content-Type': 'application/json',
    };
  }

  /**
   * 校验微信支付响应字段
   * 微信 v3 正常返回依赖业务字段而不是 body.status，因此必须显式验证关键字段
   */
  private requireWechatResponseField<T>(
    responseData: Record<string, any>,
    fieldName: string,
    actionName: string,
    fallbackErrorCode: ErrorCode = ErrorCode.PAYMENT_CREATION_FAILED,
  ): T {
    const fieldValue = responseData?.[fieldName];

    if (fieldValue !== undefined && fieldValue !== null && fieldValue !== '') {
      return fieldValue as T;
    }

    const responseErrorCode = responseData?.code;
    const errorMessage = responseData?.message || responseData?.detail;
    const detailSuffix =
      responseErrorCode || errorMessage
        ? ` code=${responseErrorCode || 'UNKNOWN'}, message=${errorMessage || '未知错误'}`
        : '';

    throw createBusinessException(
      fallbackErrorCode,
      `Wechat Pay ${actionName} failed: missing ${fieldName}.${detailSuffix}`,
    );
  }

  /**
   * 构建签名字符串
   */
  private buildSignString(
    method: string,
    url: string,
    timestamp: number,
    nonceStr: string,
    body: any,
  ): string {
    const bodyStr = method === 'GET' ? '' : JSON.stringify(body);
    return `${method}\n${url}\n${timestamp}\n${nonceStr}\n${bodyStr}\n`;
  }

  /**
   * 签名
   */
  private sign(signStr: string): string {
    const sign = crypto.createSign('SHA256');
    sign.update(signStr);
    sign.end();
    return sign.sign(this.apiclientKey, 'base64');
  }

  /**
   * 验证签名
   */
  private verifySignature(signStr: string, signature: string): boolean {
    const verify = crypto.createVerify('SHA256');
    verify.update(signStr);
    verify.end();
    return verify.verify(this.apiclientCert, signature, 'base64');
  }

  /**
   * 构建 APP 支付签名
   */
  private buildAppPaySign(
    appId: string,
    timeStamp: string,
    nonceStr: string,
    prepayId: string,
  ): string {
    const signStr = `${appId}\n${timeStamp}\n${nonceStr}\n${prepayId}\n`;
    return this.sign(signStr);
  }

  /**
   * 构建 JSAPI 支付签名
   */
  private buildJsapiPaySign(
    appId: string,
    timeStamp: string,
    nonceStr: string,
    prepayId: string,
  ): string {
    const signStr = `${appId}\n${timeStamp}\n${nonceStr}\n${prepayId}\n`;
    return this.sign(signStr);
  }

  /**
   * 解密回调数据
   */
  private decryptResource(
    ciphertext: string,
    associatedData: string,
    nonce: string,
  ): string {
    const decipher = crypto.createDecipheriv(
      'aes-256-gcm',
      this.apiKey,
      Buffer.from(nonce, 'base64'),
    );
    decipher.setAuthTag(Buffer.from(ciphertext, 'base64').slice(-16));
    decipher.setAAD(Buffer.from(associatedData, 'base64'));

    const decrypted = Buffer.concat([
      decipher.update(Buffer.from(ciphertext, 'base64').slice(0, -16)),
      decipher.final(),
    ]);
    return decrypted.toString('utf8');
  }

  /**
   * 生成随机字符串
   */
  private generateNonceStr(): string {
    return crypto.randomBytes(16).toString('hex');
  }

  /**
   * 格式化过期时间
   * 微信支付格式：RFC3339
   */
  private formatTimeExpire(expiredAt: Date): string {
    const date = new Date(expiredAt);
    return date.toISOString();
  }
}
