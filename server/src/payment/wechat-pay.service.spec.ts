import axios from 'axios';
import { ConfigService } from '@nestjs/config';
import { WechatPayService } from './wechat-pay.service';
import { Payment, PaymentMethod } from './entities/payment.entity';

jest.mock('axios');

describe('WechatPayService', () => {
  let service: WechatPayService;
  const mockedAxios = axios as jest.Mocked<typeof axios>;

  const mockConfigService = {
    get: jest.fn((key: string) => {
      const configMap: Record<string, string> = {
        WECHAT_PAY_APP_ID: 'wx-app-id',
        WECHAT_PAY_MCH_ID: 'wx-mch-id',
        WECHAT_PAY_API_KEY: 'wx-api-key',
        WECHAT_PAY_NOTIFY_URL: 'https://example.com/wechat/notify',
        WECHAT_PAY_REFUND_NOTIFY_URL: 'https://example.com/wechat/refund-notify',
      };

      return configMap[key];
    }),
  } as unknown as ConfigService;

  /**
   * 构造最小支付对象
   * 只保留本次单测真正依赖的字段，避免测试夹带无关业务噪音
   */
  const createPaymentEntity = (method: PaymentMethod): Payment =>
    ({
      outTradeNo: 'SHOP_ORDER_1_1700000000000',
      amount: 99.99,
      subject: '测试订单',
      description: '测试订单描述',
      expiredAt: new Date('2026-03-14T12:00:00.000Z'),
      method,
      metadata: {
        openid: 'openid_123',
        clientIp: '127.0.0.1',
      },
    }) as unknown as Payment;

  beforeEach(() => {
    service = new WechatPayService(mockConfigService);
    service.onModuleInit();

    jest.spyOn(service as any, 'buildSignHeaders').mockReturnValue({});
    jest.spyOn(service as any, 'buildAppPaySign').mockReturnValue('mock-app-sign');
    jest.spyOn(service as any, 'buildJsapiPaySign').mockReturnValue(
      'mock-jsapi-sign',
    );
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should accept APP payment response when prepay_id exists', async () => {
    mockedAxios.post.mockResolvedValueOnce({
      data: {
        prepay_id: 'prepay-app-1',
      },
    } as any);

    const result = await service.createPayment(
      createPaymentEntity(PaymentMethod.APP),
    );

    expect(result.wechatPrepayId).toBe('prepay-app-1');
    expect(result.wechatSign).toBe('mock-app-sign');
  });

  it('should accept JSAPI payment response when prepay_id exists', async () => {
    mockedAxios.post.mockResolvedValueOnce({
      data: {
        prepay_id: 'prepay-jsapi-1',
      },
    } as any);

    const result = await service.createPayment(
      createPaymentEntity(PaymentMethod.JSAPI),
    );

    expect(result.wechatPackage).toBe('prepay_id=prepay-jsapi-1');
    expect(result.wechatPaySign).toBe('mock-jsapi-sign');
  });

  it('should accept H5 payment response when h5_url exists', async () => {
    mockedAxios.post.mockResolvedValueOnce({
      data: {
        h5_url: 'https://wxpay.example.com/h5',
      },
    } as any);

    const result = await service.createPayment(
      createPaymentEntity(PaymentMethod.H5),
    );

    expect(result.paymentUrl).toBe('https://wxpay.example.com/h5');
  });

  it('should accept Native payment response when code_url exists', async () => {
    mockedAxios.post.mockResolvedValueOnce({
      data: {
        code_url: 'weixin://wxpay/native-code',
      },
    } as any);

    const result = await service.createPayment(
      createPaymentEntity(PaymentMethod.NATIVE),
    );

    expect(result.qrCodeUrl).toBe('weixin://wxpay/native-code');
  });

  it('should reject payment response when required field is missing', async () => {
    mockedAxios.post.mockResolvedValueOnce({
      data: {
        code: 'PARAM_ERROR',
        message: 'missing prepay id',
      },
    } as any);

    await expect(
      service.createPayment(createPaymentEntity(PaymentMethod.APP)),
    ).rejects.toThrow('missing prepay_id');
  });

  it('should accept refund response when refund_id exists', async () => {
    mockedAxios.post.mockResolvedValueOnce({
      data: {
        refund_id: 'refund-123',
      },
    } as any);

    const result = await service.createRefund(
      createPaymentEntity(PaymentMethod.APP),
      20,
      'REF_1',
      '测试退款',
    );

    expect(result).toBe('refund-123');
  });
  it('verifies the original JSON bytes instead of serializing the parsed object', async () => {
    jest.spyOn(service as any, 'ensureConfigured').mockImplementation(() => undefined);
    const verify = jest.spyOn(service as any, 'verifySignature').mockReturnValue(true);
    jest.spyOn(service as any, 'decryptResource').mockReturnValue(JSON.stringify({
      out_trade_no: 'ORDER_1', transaction_id: 'TX_1', trade_state: 'SUCCESS',
    }));
    const raw = '{ "resource" : { "ciphertext" : "abc", "nonce" : "n" } }';
    const result = await service.verifyCallback(JSON.parse(raw), {
      'wechatpay-timestamp': '123', 'wechatpay-nonce': 'nonce',
      'wechatpay-signature': 'signature',
    }, raw);
    expect(verify).toHaveBeenCalledWith(`123\nnonce\n${raw}\n`, 'signature');
    expect(result.valid).toBe(true);
  });
});
