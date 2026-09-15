import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ChatPaymentConfig } from './entities/chat-payment-config.entity';

@Injectable()
export class PaymentConfigService {
  constructor(
    @InjectRepository(ChatPaymentConfig)
    private paymentConfigRepository: Repository<ChatPaymentConfig>,
  ) {}

  async getConfig(doctorId?: number): Promise<ChatPaymentConfig> {
    let config = await this.paymentConfigRepository.findOne({
      where: { doctorId, isActive: true },
    });

    if (!config) {
      // 如果没有特定医生的配置，返回全局默认配置
      config = await this.paymentConfigRepository.findOne({
        where: { doctorId: null, isActive: true },
      });
    }

    if (!config) {
      // 创建默认配置
      const newConfig = this.paymentConfigRepository.create({
        doctorId: null,
        maxFreeReplies: 3,
        isActive: true,
      });
      config = await this.paymentConfigRepository.save(newConfig);
    }

    return config;
  }

  async updateConfig(doctorId: number, dto: any): Promise<ChatPaymentConfig> {
    const config = await this.paymentConfigRepository.findOne({
      where: { doctorId, isActive: true },
    });

    if (!config) {
      const newConfig = this.paymentConfigRepository.create({ doctorId });
      return this.paymentConfigRepository.save(newConfig);
    }

    Object.assign(config, dto);
    return this.paymentConfigRepository.save(config);
  }
}
