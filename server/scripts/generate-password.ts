/**
 * 生成加密密码脚本
 * 用于生成 bcrypt 加密后的密码
 *
 * 使用方法:
 * npm run generate-password
 * 或
 * ts-node scripts/generate-password.ts
 */

import * as bcrypt from 'bcryptjs';

// 管理员账户配置
const adminUsername = 'admin';
const adminPassword = 'admin123456';
const adminEmail = 'admin@example.com';
const adminPhone = '13800138000'; // 手机号必填

// 生成加密密码 (10 rounds)
const hash = bcrypt.hashSync(adminPassword, 10);

console.log('='.repeat(60));
console.log('管理员账户密码生成工具');
console.log('='.repeat(60));
console.log('');
console.log('📝 账户信息:');
console.log(`   用户名: ${adminUsername}`);
console.log(`   密码:   ${adminPassword}`);
console.log(`   邮箱:   ${adminEmail}`);
console.log(`   手机号: ${adminPhone}`);
console.log('');
console.log('🔒 加密密码:');
console.log(`   ${hash}`);
console.log('');
console.log('='.repeat(60));
console.log('');
console.log('💡 使用说明:');
console.log('');
console.log('【方式 1】直接在数据库中执行 SQL（如果用户不存在）:');
console.log('-'.repeat(60));
console.log(`INSERT INTO users (username, email, phone, password, role, isActive, createdAt, updatedAt)`);
console.log(`VALUES ('${adminUsername}', '${adminEmail}', '${adminPhone}', '${hash}', 'SUPER_ADMIN', 1, NOW(), NOW());`);
console.log('');

console.log('【方式 2】更新现有管理员密码（如果用户已存在）:');
console.log('-'.repeat(60));
console.log(`UPDATE users SET password = '${hash}' WHERE username = '${adminUsername}';`);
console.log('');

console.log('【方式 3】使用 INSERT ... ON DUPLICATE KEY UPDATE（推荐）:');
console.log('-'.repeat(60));
console.log(`INSERT INTO users (username, email, phone, password, role, isActive, createdAt, updatedAt)`);
console.log(`VALUES ('${adminUsername}', '${adminEmail}', '${adminPhone}', '${hash}', 'SUPER_ADMIN', 1, NOW(), NOW())`);
console.log(`ON DUPLICATE KEY UPDATE password = '${hash}', email = '${adminEmail}', updatedAt = NOW();`);
console.log('');

console.log('【方式 4】先检查用户是否存在:');
console.log('-'.repeat(60));
console.log('-- 先查询用户是否存在');
console.log(`SELECT id, username, email, phone FROM users WHERE username = '${adminUsername}';`);
console.log('');
console.log('-- 如果查询结果为空，则执行 INSERT');
console.log(`INSERT INTO users (username, email, phone, password, role, isActive, createdAt, updatedAt)`);
console.log(`VALUES ('${adminUsername}', '${adminEmail}', '${adminPhone}', '${hash}', 'SUPER_ADMIN', 1, NOW(), NOW());`);
console.log('');
console.log('-- 如果查询结果不为空，则执行 UPDATE');
console.log(`UPDATE users SET password = '${hash}', email = '${adminEmail}' WHERE username = '${adminUsername}';`);
console.log('');

console.log('='.repeat(60));

// 验证密码
const isValid = bcrypt.compareSync(adminPassword, hash);
console.log('');
console.log('✅ 密码验证:', isValid ? '成功' : '失败');
console.log('='.repeat(60));
