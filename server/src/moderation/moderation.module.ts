import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";

import { ActivityComment } from "../activities/entities/activity-comment.entity";
import { ActivityVoteOption } from "../activities/entities/activity-vote-option.entity";
import { Comment } from "../community/entities/comment.entity";
import { Post } from "../community/entities/post.entity";
import { FriendMessage } from "../friends/entities/friend-message.entity";
import { MarketplaceConversation } from "../marketplace-chat/entities/marketplace-conversation.entity";
import { MarketplaceMessage } from "../marketplace-chat/entities/marketplace-message.entity";
import { LostFoundComment } from "../lost-found/entities/lost-found-comment.entity";
import { LostFound } from "../lost-found/entities/lost-found.entity";
import { Product } from "../shop/entities/product.entity";
import { User } from "../users/entities/user.entity";
import { AdminModerationController } from "./admin-moderation.controller";
import { ModerationController } from "./moderation.controller";
import { ModerationService } from "./moderation.service";
import { UGCReport, UserBlock } from "./entities";

@Module({
  imports: [
    TypeOrmModule.forFeature([
      UGCReport,
      UserBlock,
      User,
      Post,
      Comment,
      LostFound,
      LostFoundComment,
      ActivityComment,
      ActivityVoteOption,
      Product,
      FriendMessage,
      MarketplaceConversation,
      MarketplaceMessage,
    ]),
  ],
  controllers: [ModerationController, AdminModerationController],
  providers: [ModerationService],
  exports: [ModerationService],
})
export class ModerationModule {}
