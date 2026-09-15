import { IsNotEmpty, IsString } from "class-validator";
import { ApiProperty } from "@nestjs/swagger";

/**
 * 查询上一段会话 DTO
 * 用于校验当前会话的持久化 `conversationId`
 */
export class QueryPreviousSessionDto {
  @ApiProperty({
    description: "当前会话的持久化 conversationId",
    example: "550e8400-e29b-41d4-a716-446655440000",
  })
  @IsString()
  @IsNotEmpty()
  beforeConversationId: string;
}
