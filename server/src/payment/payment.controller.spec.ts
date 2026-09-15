import { NotImplementedException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { ResponseInterceptor } from '../common/interceptors/response.interceptor';
import { PaymentController } from './payment.controller';
import { PaymentService } from './payment.service';
import { PaymentChannel, BusinessType } from './entities/payment.entity';

function createTextResponse() {
  const response = {
    type: jest.fn(),
    send: jest.fn(),
  };
  response.type.mockReturnValue(response);
  response.send.mockReturnValue(response);
  return response;
}

jest.mock('uuid', () => ({
  v4: jest.fn(() => 'mocked-id'),
}));

describe('PaymentController', () => {
  let controller: PaymentController;

  const mockPaymentService = {
    createPaymentFromBusiness: jest.fn(),
    queryPaymentStatus: jest.fn(),
    closePayment: jest.fn(),
    createRefund: jest.fn(),
    handlePaymentCallback: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [PaymentController],
      providers: [
        {
          provide: PaymentService,
          useValue: mockPaymentService,
        },
      ],
    }).compile();

    controller = module.get<PaymentController>(PaymentController);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should delegate admin create payment request to business resolver', async () => {
    const dto = {
      channel: PaymentChannel.ALIPAY,
      businessType: BusinessType.SHOP_ORDER,
      businessId: 1,
      metadata: { source: 'spec' },
    };

    mockPaymentService.createPaymentFromBusiness.mockResolvedValue({
      paymentNo: 'PAY_1',
    });

    await controller.createPayment(dto as any);

    expect(mockPaymentService.createPaymentFromBusiness).toHaveBeenCalledWith(
      dto,
    );
  });

  it('should keep create payment route restricted to admin roles', () => {
    const roles = Reflect.getMetadata('roles', controller.createPayment);

    expect(roles).toEqual(['SUPER_ADMIN', 'STAFF']);
  });

  it('should acknowledge a successful Alipay callback with plain text success', async () => {
    const callbackData = { out_trade_no: 'ORDER_1' };
    const response = createTextResponse();
    mockPaymentService.handlePaymentCallback.mockResolvedValue(undefined);

    await controller.alipayCallback(callbackData, response as any);

    expect(mockPaymentService.handlePaymentCallback).toHaveBeenCalledWith(
      PaymentChannel.ALIPAY,
      callbackData,
    );
    expect(response.type).toHaveBeenCalledWith('text/plain');
    expect(response.send).toHaveBeenCalledWith('success');
  });

  it('should acknowledge a failed Alipay callback with plain text failure', async () => {
    const response = createTextResponse();
    mockPaymentService.handlePaymentCallback.mockRejectedValue(
      new Error('invalid callback'),
    );

    await controller.alipayCallback({}, response as any);

    expect(response.type).toHaveBeenCalledWith('text/plain');
    expect(response.send).toHaveBeenCalledWith('failure');
  });

  it('should bypass the global response envelope for Alipay callbacks', async () => {
    mockPaymentService.handlePaymentCallback.mockResolvedValue(undefined);
    const testingModule = await Test.createTestingModule({
      controllers: [PaymentController],
      providers: [
        {
          provide: PaymentService,
          useValue: mockPaymentService,
        },
      ],
    }).compile();
    const app = testingModule.createNestApplication();
    app.useGlobalInterceptors(new ResponseInterceptor());
    await app.init();

    try {
      const response = await request(app.getHttpServer())
        .post('/payment/callback/alipay')
        .type('form')
        .send({ out_trade_no: 'ORDER_1' })
        .expect(200)
        .expect('Content-Type', /text\/plain/);

      expect(response.text).toBe('success');
    } finally {
      await app.close();
    }
  });

  it('should throw not implemented for payment list', async () => {
    await expect(controller.getPaymentList({} as any)).rejects.toBeInstanceOf(
      NotImplementedException,
    );
  });

  it('should throw not implemented for my payments', async () => {
    await expect(controller.getMyPayments({} as any)).rejects.toBeInstanceOf(
      NotImplementedException,
    );
  });
});


describe('WeChat callback HTTP contract', () => {
  const handlePaymentCallback = jest.fn();
  let app: any;
  beforeEach(async () => {
    handlePaymentCallback.mockReset().mockResolvedValue(undefined);
    const module = await Test.createTestingModule({
      controllers: [PaymentController],
      providers: [{ provide: PaymentService, useValue: { handlePaymentCallback } }],
    }).compile();
    app = module.createNestApplication({ rawBody: true });
    app.useGlobalInterceptors(new ResponseInterceptor());
    await app.init();
  });
  afterEach(async () => { await app.close(); });

  it('preserves exact raw JSON and returns an unwrapped acknowledgement', async () => {
    const raw = '{ "id" : "event-1", "resource" : {} }';
    const response = await request(app.getHttpServer())
      .post('/payment/callback/wechat')
      .set('Content-Type', 'application/json')
      .send(raw).expect(200);
    expect(handlePaymentCallback).toHaveBeenCalledWith(
      PaymentChannel.WECHAT, JSON.parse(raw), expect.any(Object), raw,
    );
    expect(response.body).toEqual({ code: 'SUCCESS', message: '成功' });
  });

  it('returns a non-success HTTP status when callback processing fails', async () => {
    handlePaymentCallback.mockRejectedValue(new Error('invalid signature'));
    const response = await request(app.getHttpServer())
      .post('/payment/callback/wechat').send({ id: 'event-1' }).expect(500);
    expect(response.body).toEqual({ code: 'FAIL', message: '处理失败' });
  });
});
