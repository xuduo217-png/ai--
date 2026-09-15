import { Type } from "class-transformer";
import {
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from "class-validator";
import { ApiProperty, ApiPropertyOptional } from "@nestjs/swagger";

import { MessageType } from "../../friends/entities/friend-message.entity";

export class OpenMarketplaceConversationDto {
  @ApiProperty({ description: "二手商品ID" })
  @Type(() => Number)
  @IsInt({ message: "商品ID必须是整数" })
  @Min(1, { message: "商品ID必须大于0" })
  productId: number;
}

export class QueryMarketplaceConversationsDto {
  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page = 1;

  @ApiPropertyOptional({ default: 20, maximum: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize = 20;
}

export class QueryMarketplaceMessagesDto {
  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page = 1;

  @ApiPropertyOptional({ default: 50, maximum: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize = 50;
}

export class SendMarketplaceMessageDto {
  @ApiProperty({ description: "商城会话UUID" })
  @IsNotEmpty({ message: "会话ID不能为空" })
  @IsString()
  @MaxLength(36)
  conversationId: string;

  @ApiProperty({ enum: MessageType })
  @IsEnum(MessageType, {
    message: "消息类型必须是 text、image、voice 或 video",
  })
  messageType: MessageType;

  @ApiProperty({ description: "文本或媒体JSON" })
  @IsString()
  @IsNotEmpty({ message: "消息内容不能为空" })
  @MaxLength(5000)
  content: string;

  @ApiPropertyOptional({ description: "客户端临时消息ID" })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  tempMessageId?: string;
}

export class MarkMarketplaceMessageReadDto {
  @ApiProperty({ description: "消息UUID" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(36)
  messageId: string;

  @ApiProperty({ description: "商城会话UUID" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(36)
  conversationId: string;
}
