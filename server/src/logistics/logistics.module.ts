import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LogisticsService } from './logistics.service';
import { LogisticsController } from './logistics.controller';
import { Logistics } from './entities/logistics.entity';

/**
 * 物流管理模块
 */
@Module({
  imports: [TypeOrmModule.forFeature([Logistics])],
  controllers: [LogisticsController],
  providers: [LogisticsService],
  exports: [LogisticsService],
})
export class LogisticsModule {}
