import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsInt,
  Max,
  Min,
  IsDateString,
} from "class-validator";
import { ApiProperty } from "@nestjs/swagger";

/**
 * 增量同步消息 DTO
 * 用于验证增量同步消息 API 的请求参数
 */
export class SyncMessagesDto {
  @ApiProperty({
    description: "会话级持久化标识（opaque session id）",
    example: "550e8400-e29b-41d4-a716-446655440000",
  })
  @IsString()
  @IsNotEmpty({ message: "conversationId 不能为空" })
  conversationId: string;

  @ApiProperty({
    description: "起始时间戳 (ISO 8601 格式，可选)",
    example: "2026-01-22T10:00:00.000Z",
    required: false,
  })
  @IsOptional()
  @IsDateString()
  since?: string;

  @ApiProperty({
    description: "最大返回数量 (1-100之间)",
    example: 50,
    required: false,
  })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}
