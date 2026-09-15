import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AidGuidesController } from './aid-guides.controller';
import { AidGuidesService } from './aid-guides.service';
import { AidGuide } from './entities/aid-guide.entity';
import { AidCategory } from './entities/aid-category.entity';

/**
 * 急救指南模块
 */
@Module({
  imports: [TypeOrmModule.forFeature([AidGuide, AidCategory])],
  controllers: [AidGuidesController],
  providers: [AidGuidesService],
  exports: [AidGuidesService],
})
export class AidGuidesModule {}
