import { DataSource } from 'typeorm';
import { AutoReply } from '../chat/entities/auto-reply.entity';
import { ChatPackage } from '../chat/entities/chat-package.entity';
import { ChatPaymentConfig } from '../chat/entities/chat-payment-config.entity';

export async function chatSeedData(dataSource: DataSource) {
  const autoReplyRepository = dataSource.getRepository(AutoReply);
  const packageRepository = dataSource.getRepository(ChatPackage);
  const paymentConfigRepository = dataSource.getRepository(ChatPaymentConfig);

  // ========== 默认自动回复（全局） ==========
  const defaultAutoReplies = [
    {
      doctorId: null, // null 表示全局默认
      content: '您好，很高兴为您服务！请问有什么可以帮您的？',
      triggerKeyword: '您好',
      sortOrder: 1,
      isActive: true,
    },
    {
      doctorId: null,
      content: '我们的医生会尽快回复您，请耐心等待。',
      triggerKeyword: '在吗',
      sortOrder: 2,
      isActive: true,
    },
    {
      doctorId: null,
      content:
        '如需更详细的咨询，建议购买我们的付费咨询服务，会有专属医生为您提供专业服务。',
      triggerKeyword: '付费',
      sortOrder: 3,
      isActive: true,
    },
  ];

  // ========== 默认付费配置（全局） ==========
  const defaultPaymentConfig = {
    doctorId: null, // null 表示全局默认
    maxFreeReplies: 3, // 免费自动回复次数
    enableChatPayment: true, // 启用付费聊天
    autoReplyEnabled: true, // 启用自动回复
    isActive: true,
  };

  const existingConfig = await paymentConfigRepository.findOne({
    where: { doctorId: null },
  });

  let paymentConfigId: number | null = null;
  if (!existingConfig) {
    const savedConfig = await paymentConfigRepository.save(
      paymentConfigRepository.create(defaultPaymentConfig),
    );
    paymentConfigId = savedConfig.id;
    console.log(`✅ Created default payment config`);
  } else {
    paymentConfigId = existingConfig.id;
  }

  for (const reply of defaultAutoReplies) {
    const existing = await autoReplyRepository.findOne({
      where: { doctorId: reply.doctorId, sortOrder: reply.sortOrder },
    });

    if (!existing) {
      await autoReplyRepository.save(autoReplyRepository.create(reply));
      console.log(
        `✅ Created auto reply: "${reply.content.substring(0, 30)}..."`,
      );
    }
  }

  // ========== 默认套餐 ==========
  const defaultPackages = [
    {
      name: '7天咨询服务',
      description: '7天不限次数的医生咨询服务，适合短期健康问题',
      durationDays: 7,
      price: 9.9,
      originalPrice: 19.9,
      sortOrder: 1,
      isActive: true,
      features: ['7天无限次咨询', '专业医生回复', '24小时内响应'],
    },
    {
      name: '月度会员',
      description: '30天全时段医生咨询服务，性价比最高',
      durationDays: 30,
      price: 29.9,
      originalPrice: 59.9,
      sortOrder: 2,
      isActive: true,
      features: ['30天无限次咨询', '专业医生回复', '12小时内响应', '专属客服'],
    },
    {
      name: '季度会员',
      description: '90天长期健康咨询服务，最适合有长期健康需求的用户',
      durationDays: 90,
      price: 79.9,
      originalPrice: 159.9,
      sortOrder: 3,
      isActive: true,
      features: [
        '90天无限次咨询',
        '专业医生回复',
        '8小时内响应',
        '专属客服',
        '健康档案管理',
      ],
    },
    {
      name: '年度会员',
      description: '365天全年健康守护，给宠物最贴心的长期关怀',
      durationDays: 365,
      price: 299.9,
      originalPrice: 599.9,
      sortOrder: 4,
      isActive: true,
      features: [
        '365天无限次咨询',
        '专家医生回复',
        '4小时内响应',
        '专属客服',
        '健康档案管理',
        '定期体检提醒',
        '优先预约挂号',
      ],
    },
  ];

  for (const pkg of defaultPackages) {
    const existing = await packageRepository.findOne({
      where: { name: pkg.name },
    });

    if (!existing) {
      const packageData = {
        ...pkg,
        configId: paymentConfigId,
      };
      await packageRepository.save(packageRepository.create(packageData));
      console.log(`✅ Created package: "${pkg.name}" - ¥${pkg.price}`);
    }
  }

  console.log('\n🎉 Chat seed data completed!');
}
