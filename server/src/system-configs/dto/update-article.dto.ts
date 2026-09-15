import { IsNotEmpty, IsString } from 'class-validator'

/**
 * 更新系统文章 DTO
 */
export class UpdateSystemArticleDto {
  @IsNotEmpty({ message: '文章内容不能为空' })
  @IsString()
  content: string
}
