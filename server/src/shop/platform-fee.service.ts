import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { SystemConfig } from '../system-configs/entities/system-config.entity';

/**
 * 平台手续费配置服务
 */
@Injectable()
export class PlatformFeeService {
  private readonly CONFIG_KEY = 'platform_fee_rate';
  private cache: { feeRate: number; timestamp: number } | null = null;
  private readonly CACHE_TTL = 5 * 60 * 1000; // 5分钟缓存

  constructor(
    @InjectRepository(SystemConfig)
    private systemConfigRepository: Repository<SystemConfig>,
  ) {}

  /**
   * 获取手续费率
   */
  async getPlatformFeeRate(): Promise<number> {
    // 检查缓存
    if (this.cache && Date.now() - this.cache.timestamp < this.CACHE_TTL) {
      return this.cache.feeRate;
    }

    // 从数据库读取
    const config = await this.systemConfigRepository.findOne({
      where: { configKey: this.CONFIG_KEY },
    });

    if (!config) {
      // 如果配置不存在，返回默认值 0（免费）
      return 0;
    }

    const feeRate = config.configValue?.feeRate || 0;

    // 更新缓存
    this.cache = {
      feeRate,
      timestamp: Date.now(),
    };

    return feeRate;
  }

  /**
   * 更新手续费率
   */
  async updatePlatformFeeRate(feeRate: number, adminId: number) {
    // 验证手续费率范围
    if (feeRate < 0 || feeRate > 100) {
      throw new BadRequestException('手续费率必须在 0-100 之间');
    }

    // 查找现有配置
    const config = await this.systemConfigRepository.findOne({
      where: { configKey: this.CONFIG_KEY },
    });

    if (config) {
      // 更新现有配置
      const oldFeeRate = config.configValue?.feeRate || 0;
      config.configValue = {
        ...config.configValue,
        feeRate,
      };
      config.description = `平台手续费率配置（${feeRate}%）`;

      await this.systemConfigRepository.save(config);

      // 清除缓存
      this.clearCache();

      return {
        success: true,
        message: '手续费率更新成功',
        oldFeeRate,
        newFeeRate: feeRate,
      };
    } else {
      // 创建新配置
      const newConfig = this.systemConfigRepository.create({
        configKey: this.CONFIG_KEY,
        configValue: {
          feeRate,
          category: 'platform',
        },
        description: `平台手续费率配置（${feeRate}%）`,
      });

      await this.systemConfigRepository.save(newConfig);

      // 清除缓存
      this.clearCache();

      return {
        success: true,
        message: '手续费率配置创建成功',
        newFeeRate: feeRate,
      };
    }
  }

  /**
   * 获取手续费配置详情
   */
  async getPlatformFeeConfig() {
    const feeRate = await this.getPlatformFeeRate();

    return {
      feeRate,
      description: feeRate === 0 ? '免手续费' : `手续费率 ${feeRate}%`,
    };
  }

  /**
   * 清除缓存
   */
  private clearCache(): void {
    this.cache = null;
  }
}
