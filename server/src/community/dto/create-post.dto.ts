import {
  IsString,
  IsNotEmpty,
  IsArray,
  IsOptional,
  MaxLength,
  ArrayMaxSize,
  Matches,
} from "class-validator";
import { ApiProperty, ApiPropertyOptional } from "@nestjs/swagger";

/**
 * 创建帖子 DTO
 */
export class CreatePostDto {
  /**
   * 帖子内容（文字）
   */
  @ApiProperty({
    description: "帖子内容",
    example: "今天带我家猫去体检了，一切正常！",
    maxLength: 10000,
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(10000, { message: "帖子内容不能超过 10000 字符" })
  content: string;

  /**
   * 图片列表（URL 数组）
   */
  @ApiPropertyOptional({
    description: "图片列表（最多 9 张）",
    type: [String],
    example: ["/uploads/image1.jpg", "/uploads/image2.jpg"],
  })
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(9, { message: "最多上传 9 张图片" })
  @IsOptional()
  images?: string[];

  /**
   * 视频 URL
   */
  @ApiPropertyOptional({
    description: "视频 URL",
    example: "/uploads/video1.mp4",
  })
  @IsString()
  @Matches(
    /^(\/uploads\/.+\.(mp4|mov|avi|wmv|webm|mpeg)|https?:\/\/.+\.(mp4|mov|avi|wmv|webm|mpeg))$/i,
    {
      message: "视频格式不正确",
    },
  )
  @IsOptional()
  video?: string;

  /**
   * 视频封面图 URL
   * 纯前端上传视频时会先本地抽帧，再把封面图和视频地址一起提交，避免列表页重复解码视频取帧。
   */
  @ApiPropertyOptional({
    description: "视频封面图 URL",
    example: "/uploads/community/video-cover.jpg",
  })
  @IsOptional()
  @IsString({ message: "视频封面图地址必须是字符串" })
  @MaxLength(500, { message: "视频封面图地址最多500个字符" })
  videoCover?: string;

  /**
   * 标签列表（标签名数组）
   */
  @ApiPropertyOptional({
    description:
      "标签列表（最多 10 个，每个标签必须以 # 开头，长度 2-20 字符）",
    type: [String],
    example: ["#宠物医疗", "#养猫心得"],
  })
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(10, { message: "最多添加 10 个标签" })
  @IsOptional()
  @Matches(/^#[\u4e00-\u9fa5a-zA-Z0-9]{1,19}$/, {
    each: true,
    message: "每个标签必须以 # 开头，只能包含中文、字母、数字，长度 2-20 字符",
  })
  tags?: string[];
}
