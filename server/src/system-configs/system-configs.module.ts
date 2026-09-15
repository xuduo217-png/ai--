import { Module, OnModuleInit, Logger } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SystemConfigsController } from './system-configs.controller';
import { SystemConfigsService } from './system-configs.service';
import { SystemConfig } from './entities/system-config.entity';
import { SystemArticlesController } from './system-articles.controller';
import { SystemArticlesService } from './system-articles.service';
import { SystemArticle } from './entities/system-article.entity';

@Module({
  imports: [TypeOrmModule.forFeature([SystemConfig, SystemArticle])],
  controllers: [SystemConfigsController, SystemArticlesController],
  providers: [SystemConfigsService, SystemArticlesService],
  exports: [SystemConfigsService, SystemArticlesService],
})
export class SystemConfigsModule implements OnModuleInit {
  private readonly logger = new Logger(SystemConfigsModule.name);

  constructor(private readonly systemConfigsService: SystemConfigsService) {}

  /**
   * 模块初始化时自动创建默认配置
   */
  async onModuleInit(): Promise<void> {
    try {
      await this.systemConfigsService.initDefaultConfigs();
    } catch (error) {
      this.logger.error('默认配置初始化失败，应用将继续启动', error.stack);
      // 不抛出异常，允许应用继续启动
    }
  }
}
