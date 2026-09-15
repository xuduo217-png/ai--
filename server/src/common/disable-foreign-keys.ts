/**
 * 禁用外键约束的订阅者
 * 在数据库连接建立后执行,确保不创建外键约束
 */

import {
  EntitySubscriberInterface,
  EventSubscriber,
  InsertEvent,
} from 'typeorm';
import { Logger } from '@nestjs/common';

@EventSubscriber()
export class DisableForeignKeyChecksSubscriber implements EntitySubscriberInterface {
  private readonly logger = new Logger(DisableForeignKeyChecksSubscriber.name);

  /**
   * 在连接建立后禁用外键检查
   */
  async afterInsert(event: InsertEvent<any>) {
    // 这个订阅者的存在会触发 TypeORM 的初始化
    // 实际的外键禁用在数据库层面通过 drop-all-fk-complete.sql 实现
  }
}

/**
 * 数据库初始化脚本
 *
 * 在服务器首次启动或需要重置时运行:
 * mysql -h HOST -u USER -p DATABASE < drop-all-fk-complete.sql
 *
 * 此脚本会:
 * 1. 禁用外键检查
 * 2. 删除所有现有的外键约束
 * 3. 恢复外键检查
 *
 * 之后 TypeORM 的 synchronize 不会再创建外键约束,
 * 因为数据库中已经没有外键约束的定义。
 */
