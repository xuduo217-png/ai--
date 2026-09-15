import {
  IsNotEmpty,
  IsString,
  IsEnum,
  IsOptional,
  IsNumber,
  MaxLength,
  IsDateString,
  Min,
  IsArray,
  Max,
  IsBoolean,
  IsInt,
} from "class-validator";
import { PetGender } from "../entities/pet.entity";
import { ApiProperty } from "@nestjs/swagger";
import { IsPastDate } from "../../common/decorators/is-past-date.decorator";

export class CreatePetDto {
  @ApiProperty({ description: "宠物名称", example: "旺财" })
  @IsNotEmpty()
  @IsString()
  @MaxLength(50)
  name: string;

  @ApiProperty({
    description: "宠物主人ID（创建时由系统自动设置，管理员可指定）",
    required: false,
  })
  @IsOptional()
  @IsNumber()
  ownerId?: number;

  @ApiProperty({ description: "宠物头像", required: false })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  avatar?: string;

  @ApiProperty({
    description: "一级分类ID（类型）",
    example: 1,
    required: false,
  })
  @IsOptional()
  @IsInt()
  categoryId?: number;

  @ApiProperty({
    description: "二级分类ID（种类）",
    example: 5,
    required: false,
  })
  @IsOptional()
  @IsInt()
  subCategoryId?: number;

  @ApiProperty({ description: "性别：1=弟弟，2=妹妹", example: 1 })
  @IsNotEmpty()
  @IsEnum(PetGender)
  gender: PetGender;

  @ApiProperty({
    description: "出生日期",
    example: "2020-01-01",
    required: false,
  })
  @IsOptional()
  @IsDateString()
  @IsPastDate({ message: "出生日期不能是未来日期" })
  birthDate?: string;

  @ApiProperty({ description: "体重（公斤）", example: 10.5, required: false })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(999.99)
  weight?: number;

  @ApiProperty({
    description: "标签（如：疫苗齐全、慢性病）",
    example: ["疫苗齐全", "慢性病"],
    required: false,
  })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(50, { each: true })
  tags?: string[];

  @ApiProperty({
    description: "是否绝育（true-已绝育，false-未绝育）",
    example: false,
    required: false,
  })
  @IsOptional()
  @IsBoolean()
  isNeutered?: boolean;

  /**
   * 疫苗针数作为结构化健康档案字段保存，
   * 前端可直接展示已接种进度，而不是仅依赖标签文案。
   */
  @ApiProperty({
    description: "疫苗接种针数",
    example: 3,
    required: false,
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  vaccineCount?: number;
}
