import { ApiPropertyOptional } from "@nestjs/swagger";
import { Type } from "class-transformer";
import { IsInt, IsOptional, IsString, Max, Min } from "class-validator";

/**
 * 查询社区用户列表 DTO
 * 用于关注列表、粉丝列表等社区关系页的分页查询。
 */
export class QueryCommunityUsersDto {
  /**
   * 页码
   */
  @ApiPropertyOptional({ description: "页码", example: 1, default: 1 })
  @Type(() => Number)
  @IsInt({ message: "页码必须是整数" })
  @Min(1, { message: "页码最小为1" })
  @IsOptional()
  page?: number = 1;

  /**
   * 每页数量
   */
  @ApiPropertyOptional({ description: "每页数量", example: 20, default: 20 })
  @Type(() => Number)
  @IsInt({ message: "每页数量必须是整数" })
  @Min(1, { message: "每页数量最小为1" })
  @Max(100, { message: "每页数量最大为100" })
  @IsOptional()
  limit?: number = 20;

  /**
   * 搜索关键词
   */
  @ApiPropertyOptional({
    description: "搜索关键词（昵称模糊搜索）",
    example: "小白",
  })
  @IsOptional()
  @IsString({ message: "搜索关键词必须是字符串" })
  keyword?: string;
}
