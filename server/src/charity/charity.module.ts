import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CharityController } from './charity.controller';
import { CharityService } from './charity.service';
import { Charity } from './entities/charity.entity';
import { CharityRecord } from './entities/charity-record.entity';
import { CharityArticle } from './entities/charity-article.entity';
import { AuthModule } from '../auth/auth.module';
import { User } from '../users/entities/user.entity';
import { PaymentModule } from '../payment/payment.module';

/**
 * 公益(Charity)模块
 *
 * 功能：
 * - 用户签到打卡公益
 * - 任务完成型公益
 * - 公益统计和管理
 * - 文章发布给参与者
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([Charity, CharityRecord, CharityArticle, User]),
    AuthModule,
    PaymentModule,
  ],
  controllers: [CharityController],
  providers: [CharityService],
  exports: [CharityService],
})
export class CharityModule {}
