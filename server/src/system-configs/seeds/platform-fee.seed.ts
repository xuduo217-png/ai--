import { DataSource } from 'typeorm';
import { SystemConfig } from '../entities/system-config.entity';

/**
 * 初始化平台手续费配置
 */
export const seedPlatformFeeConfig = async (dataSource: DataSource) => {
  const configRepository = dataSource.getRepository(SystemConfig);

  // 检查是否已存在手续费配置
  const existingConfig = await configRepository.findOne({
    where: { configKey: 'platform_fee_rate' },
  });

  if (existingConfig) {
    console.log('✅ 平台手续费配置已存在，跳过');
    return;
  }

  // 创建默认手续费配置（5%）
  const platformFeeConfig = configRepository.create({
    configKey: 'platform_fee_rate',
    configValue: {
      feeRate: 5, // 5%
      category: 'platform',
      description: '平台手续费率（百分比）',
    },
    description: '平台手续费率配置（0-100），0表示免手续费',
  });

  await configRepository.save(platformFeeConfig);
  console.log('✅ 平台手续费配置初始化完成（默认5%）');
};
