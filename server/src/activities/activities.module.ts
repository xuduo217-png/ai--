import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ActivitiesService } from './activities.service';
import { ActivitiesController } from './activities.controller';
import { Activity } from './entities/activity.entity';
import { ActivityComment } from './entities/activity-comment.entity';
import { ActivityRegistration } from './entities/activity-registration.entity';
import { ActivityVoteOption } from './entities/activity-vote-option.entity';
import { User } from '../users/entities/user.entity';
import { ModerationModule } from '../moderation/moderation.module';

/**
 * 活动模块
 */
@Module({
  imports: [
    ModerationModule,
    TypeOrmModule.forFeature([
      Activity,
      ActivityComment,
      ActivityRegistration,
      ActivityVoteOption,
      User,
    ]),
  ],
  controllers: [ActivitiesController],
  providers: [ActivitiesService],
  exports: [ActivitiesService],
})
export class ActivitiesModule {}
