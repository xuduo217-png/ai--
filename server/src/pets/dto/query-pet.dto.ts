import {
  IsOptional,
  IsEnum,
  IsInt,
  IsString,
  Min,
  IsBoolean,
} from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { PetGender } from '../entities/pet.entity';
import { Type } from 'class-transformer';
import { PaginationDto } from '../../common/dto/pagination.dto';

export class QueryPetDto extends PaginationDto {
  @ApiProperty({ description: '主人ID', required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  ownerId?: number;

  @ApiProperty({ description: '一级分类ID（类型）', required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  categoryId?: number;

  @ApiProperty({ description: '二级分类ID（种类）', required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  subCategoryId?: number;

  @ApiProperty({ description: '宠物名称（模糊搜索）', required: false })
  @IsOptional()
  @IsString()
  name?: string;

  @ApiProperty({
    description: '性别：1=弟弟，2=妹妹',
    required: false,
    enum: PetGender,
  })
  @IsOptional()
  @IsEnum(PetGender)
  gender?: PetGender;

  @ApiProperty({ description: '最小体重（公斤）', required: false })
  @IsOptional()
  @Type(() => Number)
  @Min(0)
  minWeight?: number;

  @ApiProperty({ description: '最大体重（公斤）', required: false })
  @IsOptional()
  @Type(() => Number)
  @Min(0)
  maxWeight?: number;

  @ApiProperty({ description: '标签（多个标签用逗号分隔）', required: false })
  @IsOptional()
  @IsString()
  tags?: string;

  @ApiProperty({
    description: '是否绝育（true-已绝育，false-未绝育）',
    required: false,
  })
  @IsOptional()
  @IsBoolean()
  isNeutered?: boolean;
}
