import { DataSource } from 'typeorm';
import { User, UserRole } from '../users/entities/user.entity';
import * as bcrypt from 'bcryptjs';

/**
 * 用户种子数据
 * 创建默认的超级管理员账户
 */
export async function userSeedData(dataSource: DataSource) {
  const userRepository = dataSource.getRepository(User);

  // ========== 默认超级管理员 ==========
  const defaultAdmin = {
    username: 'admin',
    password: await bcrypt.hash('admin123456', 10), // 默认密码: admin123456
    email: 'admin@pethospital.com',
    phone: '13800138000', // 默认手机号
    role: UserRole.SUPER_ADMIN,
    verified: true,
    isActive: true,
    avatar: null,
    hospitalId: null,
    remarks: '系统默认超级管理员账户',
  };

  // 检查是否已存在 admin 用户
  const existingAdmin = await userRepository.findOne({
    where: [{ username: 'admin' }, { phone: '13800138000' }],
  });

  if (!existingAdmin) {
    await userRepository.save(userRepository.create(defaultAdmin));
    console.log('✅ Created super admin user:');
    console.log('   Username: admin');
    console.log('   Password: admin123456');
    console.log('   Phone: 13800138000');
    console.log('   Email: admin@pethospital.com');
    console.log('   Role: SUPER_ADMIN');
  } else {
    console.log('ℹ️  Admin user already exists, skipping creation');
  }

  // ========== 创建测试用普通用户 ==========
  const testUsers = [
    {
      username: 'user1',
      password: await bcrypt.hash('123456', 10),
      phone: '13912345678',
      email: 'user1@example.com',
      role: UserRole.USER,
      verified: true,
      isActive: true,
    },
    {
      username: 'user2',
      password: await bcrypt.hash('123456', 10),
      phone: '13912345679',
      email: 'user2@example.com',
      role: UserRole.USER,
      verified: true,
      isActive: true,
    },
  ];

  for (const testUser of testUsers) {
    const existingUser = await userRepository.findOne({
      where: [{ username: testUser.username }, { phone: testUser.phone }],
    });

    if (!existingUser) {
      await userRepository.save(userRepository.create(testUser));
      console.log(`✅ Created test user:`);
      console.log(`   Username: ${testUser.username}`);
      console.log(`   Password: 123456`);
      console.log(`   Phone: ${testUser.phone}`);
      console.log(`   Role: ${testUser.role}`);
    } else {
      console.log(
        `ℹ️  Test user ${testUser.username} already exists, skipping creation`,
      );
    }
  }

  console.log('\n🎉 User seed data completed!');
}
