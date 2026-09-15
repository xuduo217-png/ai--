import { Module } from "@nestjs/common";
import { JwtModule } from "@nestjs/jwt";
import { TypeOrmModule } from "@nestjs/typeorm";

import { AuthModule } from "../auth/auth.module";
import { ModerationModule } from "../moderation/moderation.module";
import { Product } from "../shop/entities/product.entity";
import { UsersModule } from "../users/users.module";
import { MarketplaceConversation } from "./entities/marketplace-conversation.entity";
import { MarketplaceMessage } from "./entities/marketplace-message.entity";
import { MarketplaceChatController } from "./marketplace-chat.controller";
import { MarketplaceChatGateway } from "./marketplace-chat.gateway";
import { MarketplaceChatService } from "./marketplace-chat.service";

@Module({
  imports: [
    TypeOrmModule.forFeature([
      MarketplaceConversation,
      MarketplaceMessage,
      Product,
    ]),
    UsersModule,
    AuthModule,
    ModerationModule,
    JwtModule.register({}),
  ],
  controllers: [MarketplaceChatController],
  providers: [MarketplaceChatService, MarketplaceChatGateway],
  exports: [MarketplaceChatService, MarketplaceChatGateway],
})
export class MarketplaceChatModule {}
