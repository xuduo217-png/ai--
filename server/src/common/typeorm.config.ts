/**
 * TypeORM 配置服务
 * 在数据库连接建立后立即禁用外键检查
 */

import { DataSource, DataSourceOptions } from 'typeorm';

export class TypeOrmConfigService {
  constructor(private options: DataSourceOptions) {}

  createDataSource(): DataSource {
    const dataSource = new DataSource(this.options);

    // 在连接建立后立即禁用外键检查
    dataSource.initialize().then(() => {
      dataSource.query('SET FOREIGN_KEY_CHECKS = 0');
      console.log('✅ 外键检查已禁用 - 数据库将不会创建外键约束');
    });

    return dataSource;
  }
}
