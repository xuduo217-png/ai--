import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { StatisticsController } from './statistics.controller';
import { StatisticsService } from './statistics.service';
import { Hospital } from '../hospitals/entities/hospital.entity';
import { Doctor } from '../doctors/entities/doctor.entity';
import { User } from '../users/entities/user.entity';
import { Pet } from '../pets/entities/pet.entity';

/**
 * 统计数据模块
 * 提供首页统计数据接口
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([
      Hospital,
      Doctor,
      User,
      Pet,
    ]),
  ],
  controllers: [StatisticsController],
  providers: [StatisticsService],
  exports: [StatisticsService],
})
export class StatisticsModule {}
