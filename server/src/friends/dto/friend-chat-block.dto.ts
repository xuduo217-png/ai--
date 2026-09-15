import { Type } from "class-transformer";
import { IsInt, IsOptional, Max, Min } from "class-validator";
import { ApiProperty } from "@nestjs/swagger";

export class BlockFriendChatDto {
  @ApiProperty({ description: "被拉黑的好友用户ID", example: 2 })
  @Type(() => Number)
  @IsInt({ message: "用户ID必须是整数" })
  @Min(1, { message: "用户ID必须大于0" })
  blockedUserId: number;
}

export class QueryFriendChatBlocksDto {
  @ApiProperty({ description: "页码", example: 1, required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: "页码必须是整数" })
  @Min(1, { message: "页码最小为1" })
  page?: number = 1;

  @ApiProperty({ description: "每页数量", example: 20, required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: "每页数量必须是整数" })
  @Min(1, { message: "每页数量最小为1" })
  @Max(100, { message: "每页数量最大为100" })
  pageSize?: number = 20;
}
