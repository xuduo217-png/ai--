import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { CommunityController } from "./community.controller";
import { AdminCommunityController } from "./admin-community.controller";
import { PostService } from "./post.service";
import { CommentService } from "./comment.service";
import { LikeService } from "./like.service";
import { SensitiveWordModule } from "./sensitive-word.module";
import { CommunityProfileService } from "./community-profile.service";
import { CommunityFollowService } from "./community-follow.service";
import {
  Post,
  Tag,
  PostTag,
  Comment,
  Like,
  CommunityProfile,
  CommunityFollow,
} from "./entities";
import { PostOwnerGuard } from "./guards";
import { NotificationsModule } from "../notifications/notifications.module";
import { User } from "../users/entities/user.entity";
import { ModerationModule } from "../moderation/moderation.module";

/**
 * 社区模块
 * 包含帖子、评论、点赞、社区资料、关注关系、敏感词等功能
 */
@Module({
  imports: [
    SensitiveWordModule,
    NotificationsModule,
    ModerationModule,
    TypeOrmModule.forFeature([
      Post,
      Tag,
      PostTag,
      Comment,
      Like,
      CommunityProfile,
      CommunityFollow,
      User,
    ]),
  ],
  controllers: [CommunityController, AdminCommunityController],
  providers: [
    PostService,
    CommentService,
    LikeService,
    CommunityProfileService,
    CommunityFollowService,
    PostOwnerGuard,
  ],
  exports: [
    PostService,
    CommentService,
    LikeService,
    SensitiveWordModule,
    CommunityProfileService,
    CommunityFollowService,
  ],
})
export class CommunityModule {}
