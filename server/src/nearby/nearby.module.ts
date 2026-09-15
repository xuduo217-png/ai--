import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserLocation } from './entities/user-location.entity';
import { User } from '../users/entities/user.entity';
import { Friendship } from '../friends/entities/friendship.entity';
import { Pet } from '../pets/entities/pet.entity';
import { NearbyService } from './nearby.service';
import { NearbyController } from './nearby.controller';
import { NearbyScheduler } from './nearby.scheduler';

/**
 * 附近的人模块
 *
 * 功能：
 * - 附近的人查询（支持距离筛选、分页）
 * - 用户位置管理
 * - 发现开关控制
 * - 位置数据清理（定时任务）
 */
@Module({
  imports: [
    // 导入 TypeORM 实体
    TypeOrmModule.forFeature([
      UserLocation,
      User,
      Friendship,
      Pet,
    ]),
  ],
  controllers: [NearbyController],
  providers: [NearbyService, NearbyScheduler],
  exports: [NearbyService],
})
export class NearbyModule {}
