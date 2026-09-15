import { IsNotEmpty, IsString, Length, Matches, IsOptional } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

/**
 * 创建物流公司 DTO
 */
export class CreateLogisticsDto {
  @ApiProperty({ description: '物流公司名称', example: '顺丰速运' })
  @IsNotEmpty({ message: '物流公司名称不能为空' })
  @IsString()
  @Length(2, 100, { message: '名称长度在2-100个字符之间' })
  name: string;

  @ApiProperty({
    description: '物流编码（如 SF、YTO、ZTO）',
    example: 'SF',
  })
  @IsNotEmpty({ message: '物流编码不能为空' })
  @IsString()
  @Matches(/^[A-Z0-9]{2,10}$/, {
    message: '编码为2-10位大写字母或数字',
  })
  code: string;

  @ApiProperty({ description: '是否启用', required: false, default: true })
  @IsOptional()
  isEnabled?: boolean;
}
