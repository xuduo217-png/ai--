import { Module, Global } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SeedService } from './seed.service';
import { AutoReply } from '../chat/entities/auto-reply.entity';
import { ChatPackage } from '../chat/entities/chat-package.entity';
import { ChatPaymentConfig } from '../chat/entities/chat-payment-config.entity';
import { Category } from '../shop/entities/category.entity';

@Global()
@Module({
  imports: [
    TypeOrmModule.forFeature([
      AutoReply,
      ChatPackage,
      ChatPaymentConfig,
      Category,
    ]),
  ],
  providers: [SeedService],
  exports: [SeedService],
})
export class SeedModule {}
