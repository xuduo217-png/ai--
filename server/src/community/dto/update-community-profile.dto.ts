import { ApiPropertyOptional } from "@nestjs/swagger";
import { IsOptional, IsString, MaxLength } from "class-validator";

/**
 * 更新社区资料 DTO
 */
export class UpdateCommunityProfileDto {
  /**
   * 社区简介
   */
  @ApiPropertyOptional({
    description: "社区简介",
    example: "记录猫狗日常，也分享一些靠谱的养宠经验。",
  })
  @IsOptional()
  @IsString({ message: "社区简介必须是字符串" })
  @MaxLength(200, { message: "社区简介最多200个字符" })
  bio?: string;

  /**
   * 社区主页封面图
   */
  @ApiPropertyOptional({
    description: "社区主页封面图",
    example: "/uploads/community/cover.jpg",
  })
  @IsOptional()
  @IsString({ message: "封面图地址必须是字符串" })
  @MaxLength(500, { message: "封面图地址最多500个字符" })
  coverImage?: string;
}
