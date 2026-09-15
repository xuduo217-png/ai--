import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LostFoundService } from './lost-found.service';
import { LostFoundCommentsService } from './lost-found-comments.service';
import { LostFoundController } from './lost-found.controller';
import { LostFound } from './entities/lost-found.entity';
import { LostFoundComment } from './entities/lost-found-comment.entity';
import { Pet } from '../pets/entities/pet.entity';
import { User } from '../users/entities/user.entity';
import { ModerationModule } from '../moderation/moderation.module';

@Module({
  imports: [
    ModerationModule,
    TypeOrmModule.forFeature([LostFound, LostFoundComment, Pet, User]),
  ],
  controllers: [LostFoundController],
  providers: [LostFoundService, LostFoundCommentsService],
  exports: [LostFoundService, LostFoundCommentsService],
})
export class LostFoundModule {}
