import { PartialType, OmitType } from '@nestjs/swagger';
import { CreatePostDto } from './create-post.dto';

/**
 * 更新帖子 DTO
 * 继承 CreatePostDto，所有字段都变为可选
 */
export class UpdatePostDto extends PartialType(
  OmitType(CreatePostDto, [] as const)
) {}
