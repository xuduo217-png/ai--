/**
 * 创建系统用户
 * 用于发送系统消息（付费提示、支付成功等）
 *
 * 运行方式：ts-node migrations/create-system-user.ts
 */

import { DataSource } from 'typeorm';
import { User } from '../src/users/entities/user.entity';
import * as bcrypt from 'bcryptjs';

async function createSystemUser() {
  console.log('开始创建系统用户...');

  // 创建数据库连接
  const AppDataSource = new DataSource({
    type: 'mysql',
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306'),
    username: process.env.DB_USERNAME || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_DATABASE || 'pet_hospitals',
    entities: [User],
    synchronize: false,
  });

  try {
    await AppDataSource.initialize();
    console.log('数据库连接成功');

    const userRepository = AppDataSource.getRepository(User);

    // 检查系统用户是否已存在
    const existingSystemUser = await userRepository.findOne({
      where: { id: 0 },
    });

    if (existingSystemUser) {
      console.log('系统用户已存在，跳过创建');
      console.log('系统用户信息:', {
        id: existingSystemUser.id,
        username: existingSystemUser.username,
        email: existingSystemUser.email,
      });
      return;
    }

    // 创建系统用户（手动指定 ID=0）
    const result = await userRepository
      .createQueryBuilder()
      .insert()
      .into(User)
      .values({
        id: 0,
        username: 'system',
        password: await bcrypt.hash('system_password', 10),
        email: 'system@pethospital.com',
        phone: '00000000000',
        role: 'SYSTEM' as any,
        isActive: true,
        verified: true,
        avatar: null,
        gender: 0,
      })
      .execute();

    console.log('✅ 系统用户创建成功！');
    console.log('  ID: 0');
    console.log('  用户名: system');
    console.log('  邮箱: system@pethospital.com');
    console.log('  角色: SYSTEM');

  } catch (error) {
    console.error('❌ 创建系统用户失败:', error.message);
    console.error('详细错误:', error);
  } finally {
    await AppDataSource.destroy();
  }
}

createSystemUser();
