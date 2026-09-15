import { Injectable, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as tencentcloud from 'tencentcloud-sdk-nodejs';
import { SmsRecord, SmsType, SmsStatus } from './entities/sms-record.entity';
import { QuerySmsRecordDto } from './dto/query-sms-record.dto';
import { PaginatedResult } from '../common/dto/pagination.dto';

const SmsClient = tencentcloud.sms.v20210111.Client;

@Injectable()
export class SmsService {
  /**
   * 验证码有效期（秒）
   * 业务规则：验证码 2 分钟有效
   */
  private readonly verificationCodeExpiresInSeconds = 2 * 60;
  /**
   * 验证码有效期（分钟）
   * 主要用于短信模板参数展示
   */
  private readonly verificationCodeExpiresInMinutes = 2;
  private client: any;
  private appId: string;
  private signName: string;
  private templateIds: Record<string, string>;

  constructor(
    private readonly configService: ConfigService,
    @InjectRepository(SmsRecord)
    private smsRecordRepository: Repository<SmsRecord>,
  ) {
    const clientConfig = {
      credential: {
        secretId: this.configService.get<string>('SMS_SECRET_ID'),
        secretKey: this.configService.get<string>('SMS_SECRET_KEY'),
      },
      region: this.configService.get<string>('SMS_REGION') || 'ap-guangzhou',
      profile: {
        httpProfile: {
          endpoint: 'sms.tencentcloudapi.com',
        },
      },
    };

    this.client = new SmsClient(clientConfig);
    this.appId = this.configService.get<string>('SMS_APP_ID') || '';
    // 兼容两种环境变量命名，优先使用 SMS_SIGN_NAME
    this.signName =
      this.configService.get<string>('SMS_SIGN_NAME') ||
      this.configService.get<string>('SMS_SIGN') ||
      '';

    // 初始化不同业务类型的模板 ID 映射
    this.templateIds = {
      register: this.configService.get<string>('SMS_TEMPLATE_REGISTER') || '',
      reset_password: this.configService.get<string>('SMS_TEMPLATE_RESET_PASSWORD') || '',
      login: this.configService.get<string>('SMS_TEMPLATE_LOGIN') || '',
    };
  }

  /**
   * 根据业务类型获取对应的模板 ID
   * @param type 业务类型
   * @returns 模板 ID
   * @throws BadRequestException 如果类型不支持或模板 ID 未配置
   */
  private getTemplateId(type: string): string {
    const templateId = this.templateIds[type];
    if (!templateId) {
      throw new BadRequestException(
        `不支持的短信类型: ${type} 或该类型对应的模板 ID 未配置`,
      );
    }
    return templateId;
  }

  /**
   * 获取短信签名
   * 业务规则：签名必须是腾讯云短信控制台“已通过审核”的签名名称（不包含【】）
   */
  private getSignName(): string {
    if (!this.signName) {
      throw new BadRequestException(
        '短信签名未配置，请在环境变量中设置 SMS_SIGN_NAME',
      );
    }
    return this.signName;
  }

  /**
   * 提取短信发送异常消息
   * 统一提取文本，避免重复包装导致前端收到双重前缀
   */
  private extractErrorMessage(error: unknown): string {
    if (error instanceof BadRequestException) {
      const response = error.getResponse() as
        | string
        | {
            message?: string | string[];
          };
      if (typeof response === 'string') {
        return response;
      }
      if (Array.isArray(response?.message)) {
        return response.message[0] || '未知错误';
      }
      if (typeof response?.message === 'string') {
        return response.message;
      }
      return error.message;
    }

    if (error instanceof Error) {
      return error.message;
    }

    return '未知错误';
  }

  /**
   * 统一包装短信错误消息
   */
  private wrapSmsError(message: string): BadRequestException {
    // 已包含前缀时不重复拼接，避免出现“短信发送失败: 短信发送失败: ...”
    const finalMessage = message.startsWith('短信发送失败:')
      ? message
      : `短信发送失败: ${message}`;
    return new BadRequestException(finalMessage);
  }

  /**
   * 生成6位随机验证码
   */
  generateCode(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  /**
   * 发送短信验证码
   * @param phone 手机号
   * @param type 验证码类型
   * @returns 验证码和过期时间
   */
  async sendVerificationCode(
    phone: string,
    type: string,
  ): Promise<{ code: string; expiresIn: number }> {
    const code = this.generateCode();
    const templateId = this.getTemplateId(type); // 根据类型获取模板 ID

    // 保存发送记录（初始状态为 PENDING）
    // 注册和登录模板需要记录分钟数参数
    const recordParams =
      type === 'register' || type === 'login'
        ? { code, minutes: this.verificationCodeExpiresInMinutes }
        : { code };

    const smsRecord = this.smsRecordRepository.create({
      phone,
      type: type as SmsType,
      code,
      templateId, // 使用动态获取的模板 ID
      status: SmsStatus.PENDING,
      params: recordParams,
      expiresIn: this.verificationCodeExpiresInSeconds,
    });

    try {
      // 根据模板类型确定模板参数
      // 注册和登录模板需要2个参数（验证码+分钟数），重置密码模板只需要1个参数（验证码）
      const templateParams =
        type === 'register' || type === 'login'
          ? [code, String(this.verificationCodeExpiresInMinutes)] // 验证码和有效分钟数
          : [code]; // 重置密码只需要验证码

      const params = {
        PhoneNumberSet: [`+86${phone}`],
        SmsSdkAppId: this.appId,
        SignName: this.getSignName(),
        TemplateId: templateId, // 使用动态获取的模板 ID
        TemplateParamSet: templateParams,
      };

      const response = await this.client.SendSms(params);
      const status = response.SendStatusSet?.[0];

      if (!status || status.Code !== 'Ok') {
        // 更新记录为 FAILED
        smsRecord.status = SmsStatus.FAILED;
        smsRecord.errorMessage = status?.Message || '未知错误';
        await this.smsRecordRepository.save(smsRecord);
        throw this.wrapSmsError(status?.Message || '未知错误');
      }

      // 更新记录为 SENT
      smsRecord.status = SmsStatus.SENT;
      smsRecord.requestId = status.RequestId;
      await this.smsRecordRepository.save(smsRecord);

      return {
        code,
        expiresIn: this.verificationCodeExpiresInSeconds,
      };
    } catch (error) {
      const errorMessage = this.extractErrorMessage(error);
      // 更新记录为 FAILED
      smsRecord.status = SmsStatus.FAILED;
      smsRecord.errorMessage = errorMessage;
      await this.smsRecordRepository.save(smsRecord);

      throw this.wrapSmsError(errorMessage);
    }
  }

  /**
   * 保存短信记录
   */
  async saveSmsRecord(data: {
    phone: string;
    type: SmsType;
    code?: string;
    templateId: string;
    params?: Record<string, any>;
    status?: SmsStatus;
  }): Promise<SmsRecord> {
    const smsRecord = this.smsRecordRepository.create({
      phone: data.phone,
      type: data.type,
      code: data.code,
      templateId: data.templateId,
      params: data.params,
      status: data.status || SmsStatus.PENDING,
    });

    return this.smsRecordRepository.save(smsRecord);
  }

  /**
   * 查询短信记录列表
   */
  async getSmsRecords(
    query: QuerySmsRecordDto,
  ): Promise<PaginatedResult<SmsRecord>> {
    const {
      page,
      pageSize,
      sortOrder,
      sortBy,
      phone,
      type,
      status,
      startDate,
      endDate,
    } = query;

    const queryBuilder =
      this.smsRecordRepository.createQueryBuilder('smsRecord');

    // 应用筛选条件
    if (phone) {
      queryBuilder.andWhere('smsRecord.phone = :phone', { phone });
    }

    if (type) {
      queryBuilder.andWhere('smsRecord.type = :type', { type });
    }

    if (status) {
      queryBuilder.andWhere('smsRecord.status = :status', { status });
    }

    if (startDate) {
      queryBuilder.andWhere('smsRecord.sentAt >= :startDate', {
        startDate: new Date(startDate),
      });
    }

    if (endDate) {
      queryBuilder.andWhere('smsRecord.sentAt <= :endDate', {
        endDate: new Date(endDate + ' 23:59:59'),
      });
    }

    // 应用排序
    const order = sortOrder === 'ASC' ? 'ASC' : 'DESC';
    queryBuilder.orderBy(`smsRecord.${sortBy}`, order);

    // 应用分页
    const skip = (page - 1) * pageSize;
    queryBuilder.skip(skip).take(pageSize);

    const [data, total] = await queryBuilder.getManyAndCount();

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 获取短信统计信息
   */
  async getSmsStats(
    phone?: string,
    startDate?: Date,
    endDate?: Date,
  ): Promise<{
    total: number;
    byStatus: Record<string, number>;
    byType: Record<string, number>;
    successRate: number;
  }> {
    const queryBuilder =
      this.smsRecordRepository.createQueryBuilder('smsRecord');

    if (phone) {
      queryBuilder.andWhere('smsRecord.phone = :phone', { phone });
    }

    if (startDate) {
      queryBuilder.andWhere('smsRecord.sentAt >= :startDate', { startDate });
    }

    if (endDate) {
      queryBuilder.andWhere('smsRecord.sentAt <= :endDate', { endDate });
    }

    const records = await queryBuilder.getMany();

    const total = records.length;
    const byStatus: Record<string, number> = {};
    const byType: Record<string, number> = {};
    let successCount = 0;

    records.forEach((record) => {
      // 统计状态
      const status = record.status;
      byStatus[status] = (byStatus[status] || 0) + 1;

      // 统计类型
      const type = record.type;
      byType[type] = (byType[type] || 0) + 1;

      // 统计成功数量
      if (record.status === SmsStatus.SENT) {
        successCount++;
      }
    });

    const successRate = total > 0 ? (successCount / total) * 100 : 0;

    return {
      total,
      byStatus,
      byType,
      successRate: Math.round(successRate * 100) / 100,
    };
  }

  /**
   * 更新短信状态
   */
  async updateSmsStatus(
    id: number,
    status: SmsStatus,
    requestId?: string,
    errorMessage?: string,
  ): Promise<void> {
    await this.smsRecordRepository.update(id, {
      status,
      requestId,
      errorMessage,
    });
  }

  /**
   * 验证手机号格式
   */
  validatePhone(phone: string): boolean {
    const phoneRegex = /^1[3-9]\d{9}$/;
    return phoneRegex.test(phone);
  }
}
