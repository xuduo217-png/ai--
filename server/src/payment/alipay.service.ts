import {
  Injectable,
  Logger,
  OnModuleInit,
  BadRequestException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AlipaySdk } from 'alipay-sdk';
import {
  Payment,
  PaymentChannel,
  PaymentMethod,
} from './entities/payment.entity';
import {
  createBusinessException,
  ErrorCode,
} from '../common/constants/error-codes';
import { toNumber } from '../common/utils/currency.util';

export interface AlipayCallbackVerification {
  valid: boolean;
  outTradeNo: string | null;
  tradeNo: string | null;
  totalAmount: string | null;
  appId: string | null;
  sellerId: string | null;
}

export interface AlipayTransferInput {
  outBizNo: string;
  amount: string;
  payeeAccount: string;
  payeeName: string;
  orderTitle: string;
}

export interface AlipayTransferResult {
  state: 'success' | 'failed' | 'unknown';
  externalStatus: string;
  alipayOrderId?: string;
  payFundOrderId?: string;
  failureCode?: string;
  failureMessage?: string;
}

/**
 * 支付宝支付服务
 * 文档：https://opendocs.alipay.com/open/02ivbs
 */
@Injectable()
export class AlipayService implements OnModuleInit {
  private readonly logger = new Logger(AlipayService.name);
  private alipaySdk: InstanceType<typeof AlipaySdk>;
  private gateway: string;
  private appId: string;
  private sellerId: string;
  private transferSceneName: string;
  private transferSceneReportInfoType: string;
  private transferSceneReportInfoContent: string;
  private transferConfigurationReady = false;
  private configurationError: string | null = null;

  constructor(private configService: ConfigService) {}

  /**
   * 确保 SDK 已初始化
   * @private
   */
  private ensureSdkInitialized() {
    if (!this.alipaySdk) {
      throw createBusinessException(
        ErrorCode.CONFIGURATION_ERROR,
        'Alipay SDK is not configured. Please set ALIPAY_APP_ID and ALIPAY_PRIVATE_KEY in .env',
      );
    }
  }

  private ensureTransferConfigured() {
    this.ensureSdkInitialized();
    if (!this.transferConfigurationReady) {
      throw createBusinessException(
        ErrorCode.CONFIGURATION_ERROR,
        this.configurationError || '支付宝转账配置不完整',
      );
    }
  }

  onModuleInit() {
    const appId = this.configService.get('ALIPAY_APP_ID');
    const privateKey = this.configService.get('ALIPAY_PRIVATE_KEY');
    const alipayPublicKey = this.configService
      .get<string>('ALIPAY_PUBLIC_KEY')
      ?.trim();
    const appCertPath = this.configService
      .get<string>('ALIPAY_APP_CERT_PATH')
      ?.trim();
    const alipayPublicCertPath = this.configService
      .get<string>('ALIPAY_PUBLIC_CERT_PATH')
      ?.trim();
    const alipayRootCertPath = this.configService
      .get<string>('ALIPAY_ROOT_CERT_PATH')
      ?.trim();
    this.transferSceneName = this.configService
      .get<string>('ALIPAY_TRANSFER_SCENE_NAME')
      ?.trim();
    this.transferSceneReportInfoType = this.configService
      .get<string>('ALIPAY_TRANSFER_SCENE_REPORT_INFO_TYPE')
      ?.trim();
    this.transferSceneReportInfoContent = this.configService
      .get<string>('ALIPAY_TRANSFER_SCENE_REPORT_INFO_CONTENT')
      ?.trim();
    this.appId = appId?.trim();
    this.sellerId = this.configService.get('ALIPAY_SELLER_ID')?.trim();
    this.gateway =
      this.configService.get('ALIPAY_GATEWAY') ||
      'https://openapi.alipay.com/gateway.do';

    // 如果未配置支付宝,则不初始化 SDK(开发环境)
    if (!appId || !privateKey) {
      this.logger.warn(
        'Alipay credentials not configured, payment features will be disabled',
      );
      return;
    }

    const certificateValues = [
      appCertPath,
      alipayPublicCertPath,
      alipayRootCertPath,
    ];
    const configuredCertificateCount = certificateValues.filter(Boolean).length;
    if (configuredCertificateCount > 0 && configuredCertificateCount < 3) {
      this.configurationError = '支付宝证书模式配置不完整';
      this.logger.error(this.configurationError);
      return;
    }

    const certificateMode = configuredCertificateCount === 3;

    // 初始化支付宝 SDK
    try {
      this.alipaySdk = new AlipaySdk({
        appId,
        privateKey,
        ...(certificateMode
          ? {
              appCertPath,
              alipayPublicCertPath,
              alipayRootCertPath,
            }
          : { alipayPublicKey }),
        gateway: this.gateway,
        charset: 'utf-8',
        version: '1.0',
        signType: 'RSA2',
      });
    } catch (error) {
      this.configurationError = '支付宝密钥或证书无法加载';
      const errorMessage =
        error instanceof Error ? error.message : '未知的支付宝配置错误';
      this.logger.error(`${this.configurationError}: ${errorMessage}`);
      return;
    }

    const transferSignatureConfigured =
      certificateMode || Boolean(alipayPublicKey);
    const transferSceneConfigured = Boolean(
      this.transferSceneName &&
        this.transferSceneReportInfoType &&
        this.transferSceneReportInfoContent,
    );
    this.transferConfigurationReady =
      transferSignatureConfigured && transferSceneConfigured;
    if (!transferSignatureConfigured) {
      this.configurationError = '支付宝转账验签公钥或证书未配置';
    } else if (!this.transferSceneName) {
      this.configurationError = '支付宝转账场景未配置';
    } else if (
      !this.transferSceneReportInfoType ||
      !this.transferSceneReportInfoContent
    ) {
      this.configurationError = '支付宝转账场景上报信息未配置';
    }

    this.logger.log(
      `Alipay SDK initialized (${certificateMode ? 'certificate mode' : 'public key mode'})`,
    );
    if (this.transferConfigurationReady) {
      this.logger.log(
        `Alipay transfer initialized (scene: ${this.transferSceneName})`,
      );
    } else {
      this.logger.warn(`Alipay transfer disabled: ${this.configurationError}`);
    }
  }

  isTransferConfigured(): boolean {
    return Boolean(this.alipaySdk) && this.transferConfigurationReady;
  }

  getTransferConfigurationError(): string | null {
    return this.configurationError;
  }

  async createTransfer(
    input: AlipayTransferInput,
  ): Promise<AlipayTransferResult> {
    this.ensureTransferConfigured();
    try {
      const result = await this.alipaySdk.exec(
        'alipay.fund.trans.uni.transfer',
        {
          bizContent: {
            outBizNo: input.outBizNo,
            transAmount: input.amount,
            productCode: 'TRANS_ACCOUNT_NO_PWD',
            bizScene: 'DIRECT_TRANSFER',
            transferSceneName: this.transferSceneName,
            transferSceneReportInfos: [
              {
                infoType: this.transferSceneReportInfoType,
                infoContent: this.transferSceneReportInfoContent,
              },
            ],
            orderTitle: input.orderTitle,
            payeeInfo: {
              identity: input.payeeAccount,
              identityType: 'ALIPAY_LOGON_ID',
              name: input.payeeName,
            },
          },
        },
      );
      const normalized = this.normalizeTransferResult(result);
      if (normalized.state === 'failed') {
        this.logger.warn(
          `Alipay transfer rejected: ${input.outBizNo}, code: ${normalized.failureCode}`,
        );
      }
      return normalized;
    } catch {
      this.logger.warn(`Alipay transfer result unknown: ${input.outBizNo}`);
      return {
        state: 'unknown',
        externalStatus: 'UNKNOWN',
        failureCode: 'NETWORK_UNKNOWN',
        failureMessage: '支付宝转账结果待查询确认',
      };
    }
  }

  async queryTransfer(outBizNo: string): Promise<AlipayTransferResult> {
    this.ensureSdkInitialized();
    try {
      const result = await this.alipaySdk.exec(
        'alipay.fund.trans.common.query',
        {
          bizContent: {
            outBizNo,
            productCode: 'TRANS_ACCOUNT_NO_PWD',
            bizScene: 'DIRECT_TRANSFER',
          },
        },
      );
      return this.normalizeTransferResult(result);
    } catch {
      this.logger.warn(`Alipay transfer query result unknown: ${outBizNo}`);
      return {
        state: 'unknown',
        externalStatus: 'UNKNOWN',
        failureCode: 'NETWORK_UNKNOWN',
        failureMessage: '支付宝转账查询结果暂不明确',
      };
    }
  }

  private normalizeTransferResult(result: any): AlipayTransferResult {
    const status = String(result?.status || '').toUpperCase();
    const common = {
      externalStatus: status || (result?.code === '10000' ? 'UNKNOWN' : 'FAIL'),
      ...(result?.orderId ? { alipayOrderId: String(result.orderId) } : {}),
      ...(result?.payFundOrderId
        ? { payFundOrderId: String(result.payFundOrderId) }
        : {}),
    };

    if (result?.code === '10000' && status === 'SUCCESS') {
      return { state: 'success', ...common };
    }
    if (status === 'FAIL' || (result?.code && result.code !== '10000')) {
      const failureCode = String(
        result?.subCode || result?.sub_code || result?.code,
      );
      return {
        state: 'failed',
        ...common,
        externalStatus: 'FAIL',
        failureCode,
        failureMessage:
          failureCode === 'TRANSFER_SCENE_NAME_BLANK'
            ? '支付宝转账场景未配置'
            : '支付宝明确拒绝该笔转账',
      };
    }
    return { state: 'unknown', ...common };
  }

  /**
   * 创建支付
   */
  async createPayment(payment: Payment): Promise<any> {
    this.ensureSdkInitialized();

    const { paymentNo, outTradeNo, subject, body, method, expiredAt } =
      payment;
    const amount = toNumber(payment.amount as number | string);
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException('支付金额必须是大于 0 的有效数字');
    }

    try {
      // 根据支付方式调用不同的接口
      if (method === PaymentMethod.APP) {
        return await this.createAppPayment(
          paymentNo,
          outTradeNo,
          amount,
          subject,
          body,
          expiredAt,
        );
      } else if (method === PaymentMethod.WEB || method === PaymentMethod.H5) {
        return await this.createWebPayment(
          paymentNo,
          outTradeNo,
          amount,
          subject,
          body,
          expiredAt,
        );
      } else if (method === PaymentMethod.NATIVE) {
        return await this.createNativePayment(
          paymentNo,
          outTradeNo,
          amount,
          subject,
          body,
          expiredAt,
        );
      } else {
        throw new BadRequestException(`Unsupported payment method: ${method}`);
      }
    } catch (error) {
      this.logger.error(
        `Create alipay payment failed: ${error.message}`,
        error.stack,
      );
      throw error;
    }
  }

  /**
   * APP 支付
   * 返回 orderString 给客户端，客户端使用 SDK 调起支付
   */
  private async createAppPayment(
    paymentNo: string,
    outTradeNo: string,
    amount: number,
    subject: string,
    body: string,
    expiredAt: Date,
  ): Promise<{ alipayOrderString: string }> {
    const timeoutExpress = this.calculateTimeoutExpress(expiredAt);

    const orderString = this.alipaySdk.sdkExecute('alipay.trade.app.pay', {
      notifyUrl: this.configService.get('ALIPAY_NOTIFY_URL'),
      bizContent: {
        outTradeNo,
        totalAmount: amount.toFixed(2),
        subject,
        body,
        timeoutExpress,
        productCode: 'QUICK_MSECURITY_PAY',
      },
    });

    this.logger.log(
      `Alipay APP payment created: ${outTradeNo}, amount: ${amount}`,
    );

    return { alipayOrderString: orderString };
  }

  /**
   * 网页支付（PC 网站支付）
   * 返回支付表单 HTML
   */
  private async createWebPayment(
    paymentNo: string,
    outTradeNo: string,
    amount: number,
    subject: string,
    body: string,
    expiredAt: Date,
  ): Promise<{ paymentHtml: string; paymentUrl: string }> {
    const timeoutExpress = this.calculateTimeoutExpress(expiredAt);

    // 生成表单 HTML (POST)
    const paymentHtml = this.alipaySdk.pageExecute(
      'alipay.trade.page.pay',
      'POST',
      {
        returnUrl: this.configService.get('ALIPAY_RETURN_URL'),
        notifyUrl: this.configService.get('ALIPAY_NOTIFY_URL'),
        bizContent: {
          outTradeNo,
          productCode: 'FAST_INSTANT_TRADE_PAY',
          totalAmount: amount.toFixed(2),
          subject,
          body,
          timeoutExpress,
        },
      },
    );

    // 生成支付 URL (GET)
    const paymentUrlQuery = this.alipaySdk.pageExecute(
      'alipay.trade.page.pay',
      'GET',
      {
        returnUrl: this.configService.get('ALIPAY_RETURN_URL'),
        notifyUrl: this.configService.get('ALIPAY_NOTIFY_URL'),
        bizContent: {
          outTradeNo,
          productCode: 'FAST_INSTANT_TRADE_PAY',
          totalAmount: amount.toFixed(2),
          subject,
          body,
          timeoutExpress,
        },
      },
    );

    this.logger.log(
      `Alipay web payment created: ${outTradeNo}, amount: ${amount}`,
    );

    return {
      paymentHtml,
      paymentUrl: `${this.gateway}?${paymentUrlQuery}`,
    };
  }

  /**
   * 扫码支付（当面付）
   * 返回二维码内容
   */
  private async createNativePayment(
    paymentNo: string,
    outTradeNo: string,
    amount: number,
    subject: string,
    body: string,
    expiredAt: Date,
  ): Promise<{ qrCodeUrl: string }> {
    const timeoutExpress = this.calculateTimeoutExpress(expiredAt);

    const result = await this.alipaySdk.exec('alipay.trade.precreate', {
      notifyUrl: this.configService.get('ALIPAY_NOTIFY_URL'),
      bizContent: {
        outTradeNo,
        totalAmount: amount.toFixed(2),
        subject,
        body,
        timeoutExpress,
      },
    });

    if (result.code !== '10000') {
      throw createBusinessException(
        ErrorCode.PAYMENT_CREATION_FAILED,
        `Alipay native payment failed: ${result.msg}`,
      );
    }

    this.logger.log(
      `Alipay native payment created: ${outTradeNo}, amount: ${amount}`,
    );

    return { qrCodeUrl: result.qrCode };
  }

  /**
   * 验证回调签名
   * 安全修复：除了验证签名，还必须验证交易状态
   * 只有 TRADE_SUCCESS 或 TRADE_FINISHED 才视为有效支付
   */
  async verifyCallback(
    callbackData: any,
  ): Promise<AlipayCallbackVerification> {
    this.ensureSdkInitialized();

    try {
      // 1. 验证签名
      const signVerified = this.alipaySdk.checkNotifySignV2(callbackData);

      if (!signVerified) {
        this.logger.warn('Alipay callback signature verification failed');
        return {
          valid: false,
          outTradeNo: null,
          tradeNo: null,
          totalAmount: null,
          appId: null,
          sellerId: null,
        };
      }

      const outTradeNo = callbackData.out_trade_no;
      const tradeNo = callbackData.trade_no;
      const totalAmount = callbackData.total_amount;
      const callbackAppId = callbackData.app_id;
      const callbackSellerId = callbackData.seller_id;
      const tradeStatus = callbackData.trade_status;

      if (!callbackAppId || callbackAppId !== this.appId) {
        this.logger.warn(
          `Alipay callback app id mismatch: expected=${this.appId}, actual=${callbackAppId}`,
        );
        return {
          valid: false,
          outTradeNo: null,
          tradeNo: null,
          totalAmount: null,
          appId: callbackAppId || null,
          sellerId: callbackSellerId || null,
        };
      }

      if (this.sellerId && callbackSellerId !== this.sellerId) {
        this.logger.warn(
          `Alipay callback seller id mismatch: expected=${this.sellerId}, actual=${callbackSellerId}`,
        );
        return {
          valid: false,
          outTradeNo: null,
          tradeNo: null,
          totalAmount: null,
          appId: callbackAppId,
          sellerId: callbackSellerId || null,
        };
      }

      if (!outTradeNo || !tradeNo || !totalAmount) {
        this.logger.warn('Alipay callback missing required payment fields');
        return {
          valid: false,
          outTradeNo: null,
          tradeNo: null,
          totalAmount: null,
          appId: callbackAppId,
          sellerId: callbackSellerId || null,
        };
      }

      // 2. 验证交易状态（安全关键）
      // TRADE_SUCCESS: 交易成功
      // TRADE_FINISHED: 交易完结（退款期限已过）
      // TRADE_CLOSED: 交易关闭（未付款超时或全额退款）
      // WAIT_BUYER_PAY: 等待买家付款
      if (tradeStatus !== 'TRADE_SUCCESS' && tradeStatus !== 'TRADE_FINISHED') {
        this.logger.warn(
          `Alipay trade status not success: ${outTradeNo}, status: ${tradeStatus}`,
        );
        return {
          valid: false,
          outTradeNo: null,
          tradeNo: null,
          totalAmount: null,
          appId: callbackAppId,
          sellerId: callbackSellerId || null,
        };
      }

      this.logger.log(
        `Alipay callback verified: ${outTradeNo}, status: ${tradeStatus}`,
      );

      return {
        valid: true,
        outTradeNo,
        tradeNo,
        totalAmount: String(totalAmount),
        appId: callbackAppId,
        sellerId: callbackSellerId || null,
      };
    } catch (error) {
      this.logger.error(
        `Verify alipay callback failed: ${error.message}`,
        error.stack,
      );
      return {
        valid: false,
        outTradeNo: null,
        tradeNo: null,
        totalAmount: null,
        appId: null,
        sellerId: null,
      };
    }
  }

  /**
   * 查询支付状态
   */
  async queryPayment(payment: Payment): Promise<string> {
    this.ensureSdkInitialized();

    try {
      const result = await this.alipaySdk.exec('alipay.trade.query', {
        bizContent: {
          outTradeNo: payment.outTradeNo,
        },
      });

      if (result.code !== '10000') {
        throw createBusinessException(
          ErrorCode.PAYMENT_QUERY_FAILED,
          `Alipay query failed: ${result.msg}`,
        );
      }

      const tradeStatus = result.tradeStatus;
      this.logger.log(
        `Alipay payment queried: ${payment.outTradeNo}, status: ${tradeStatus}`,
      );

      return tradeStatus;
    } catch (error) {
      this.logger.error(
        `Query alipay payment failed: ${error.message}`,
        error.stack,
      );
      throw error;
    }
  }

  /**
   * 关闭支付
   */
  async closePayment(payment: Payment): Promise<void> {
    this.ensureSdkInitialized();

    try {
      const result = await this.alipaySdk.exec('alipay.trade.close', {
        bizContent: {
          outTradeNo: payment.outTradeNo,
        },
      });

      const subCode = result.subCode || result.sub_code;
      if (result.code !== '10000' && subCode !== 'ACQ.TRADE_NOT_EXIST') {
        throw createBusinessException(
          ErrorCode.PAYMENT_CLOSE_FAILED,
          `Alipay close failed: ${subCode || result.msg}`,
        );
      }

      if (subCode === 'ACQ.TRADE_NOT_EXIST') {
        this.logger.log(
          `Alipay payment was not created and needs no close: ${payment.outTradeNo}`,
        );
        return;
      }

      this.logger.log(`Alipay payment closed: ${payment.outTradeNo}`);
    } catch (error) {
      this.logger.error(
        `Close alipay payment failed: ${error.message}`,
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
    this.ensureSdkInitialized();

    try {
      const result = await this.alipaySdk.exec('alipay.trade.refund', {
        bizContent: {
          outTradeNo: payment.outTradeNo,
          refundAmount: refundAmount.toFixed(2),
          refundReason: reason || '正常退款',
          outRequestNo: refundNo,
        },
      });

      if (result.code !== '10000') {
        throw createBusinessException(
          ErrorCode.REFUND_FAILED,
          `Alipay refund failed: ${result.msg}`,
        );
      }

      this.logger.log(
        `Alipay refund created: ${refundNo}, amount: ${refundAmount}`,
      );

      return result.refundId; // 支付宝退款单号
    } catch (error) {
      this.logger.error(
        `Create alipay refund failed: ${error.message}`,
        error.stack,
      );
      throw error;
    }
  }

  /**
   * 计算超时时间
   * 支付宝格式：30m, 2h, 1d 等
   */
  private calculateTimeoutExpress(expiredAt: Date): string {
    const now = Date.now();
    const expired = new Date(expiredAt).getTime();
    const diffMinutes = Math.floor((expired - now) / (1000 * 60));

    if (diffMinutes <= 0) {
      return '30m'; // 默认30分钟
    }

    if (diffMinutes < 60) {
      return `${diffMinutes}m`;
    } else if (diffMinutes < 1440) {
      return `${Math.floor(diffMinutes / 60)}h`;
    } else {
      return `${Math.floor(diffMinutes / 1440)}d`;
    }
  }

  /**
   * 查询退款状态
   */
  async queryRefund(payment: Payment, refundNo: string): Promise<any> {
    this.ensureSdkInitialized();

    try {
      const result = await this.alipaySdk.exec(
        'alipay.trade.fastpay.refund.query',
        {
          bizContent: {
            outTradeNo: payment.outTradeNo,
            outRequestNo: refundNo,
          },
        },
      );

      if (result.code !== '10000') {
        throw createBusinessException(
          ErrorCode.REFUND_FAILED,
          `Alipay refund query failed: ${result.msg}`,
        );
      }

      this.logger.log(`Alipay refund queried: ${refundNo}`);

      return result;
    } catch (error) {
      this.logger.error(
        `Query alipay refund failed: ${error.message}`,
        error.stack,
      );
      throw error;
    }
  }
}
