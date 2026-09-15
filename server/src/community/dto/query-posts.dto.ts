import { IsEnum, IsOptional, IsInt, Min, IsString } from "class-validator";
import { Type } from "class-transformer";
import { ApiPropertyOptional } from "@nestjs/swagger";

/**
 * 帖子查询类型枚举
 */
export enum PostQueryType {
  FOLLOWING = "following", // 关注流（已关注用户的帖子）
  RECOMMEND = "recommend", // 推荐流（按热度排序）
}

/**
 * 查询帖子列表 DTO
 */
export class QueryPostsDto {
  /**
   * 查询类型（following: 关注流, recommend: 推荐流）
   */
  @ApiPropertyOptional({
    description: "查询类型",
    enum: PostQueryType,
    example: PostQueryType.RECOMMEND,
  })
  @IsEnum(PostQueryType)
  @IsOptional()
  type?: PostQueryType;

  /**
   * 标签筛选（按标签查询）
   */
  @ApiPropertyOptional({ description: "标签筛选", example: "#宠物医疗" })
  @IsString()
  @IsOptional()
  tag?: string;

  /**
   * 页码
   */
  @ApiPropertyOptional({ description: "页码", example: 1, default: 1 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @IsOptional()
  page?: number = 1;

  /**
   * 每页数量
   */
  @ApiPropertyOptional({ description: "每页数量", example: 10, default: 10 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @IsOptional()
  limit?: number = 10;
}
