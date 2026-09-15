import { ApiProperty, ApiPropertyOptional } from "@nestjs/swagger";
import { Type } from "class-transformer";
import { IsInt, IsOptional, IsString, MaxLength, Min } from "class-validator";

export class BlockUserDto {
  @ApiProperty({ description: "被屏蔽用户ID", example: 8 })
  @Type(() => Number)
  @IsInt({ message: "被屏蔽用户ID必须是整数" })
  @Min(1, { message: "被屏蔽用户ID必须为正整数" })
  blockedUserId: number;

  @ApiPropertyOptional({ description: "屏蔽原因", maxLength: 200 })
  @IsOptional()
  @IsString({ message: "屏蔽原因必须是字符串" })
  @MaxLength(200, { message: "屏蔽原因最多200字符" })
  reason?: string;
}
