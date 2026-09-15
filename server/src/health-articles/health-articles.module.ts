import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HealthArticlesController } from './health-articles.controller';
import { HealthArticlesService } from './health-articles.service';
import { HealthArticle } from './entities/health-article.entity';
import { HealthCategory } from './entities/health-category.entity';

/**
 * 健康知识模块
 * 提供健康文章和分类管理功能
 */
@Module({
  imports: [TypeOrmModule.forFeature([HealthArticle, HealthCategory])],
  controllers: [HealthArticlesController],
  providers: [HealthArticlesService],
  exports: [HealthArticlesService],
})
export class HealthArticlesModule {}
