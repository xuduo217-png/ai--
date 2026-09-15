import { Transform, Type } from "class-transformer";
import {
  IsString,
  IsNumber,
  IsBoolean,
  IsArray,
  IsInt,
  Min,
  IsEnum,
  MaxLength,
} from "class-validator";
import { ProductCondition } from "../entities/product-pending.entity";

/**
 * 创建/编辑二手商品 DTO
 */
export class CreateProductPendingDto {
  @IsString()
  @MaxLength(50, { message: "商品标题最多50个字符" })
  title: string;

  @IsString()
  description: string;

  @IsNumber({}, { message: "价格必须是数字" })
  @Min(0.01, { message: "价格必须大于0" })
  price: number;

  @Transform(({ value }) => {
    if (value === undefined || value === null || value === "") {
      return 1;
    }
    return value;
  })
  @Type(() => Number)
  @IsInt({ message: "库存必须是整数" })
  @Min(1, { message: "库存最小为1" })
  stock: number = 1;

  @IsBoolean()
  negotiable: boolean;

  @IsArray()
  @IsString({ each: true })
  images: string[];

  @IsNumber({}, { message: "商品分类ID必须是数字" })
  categoryId: number;

  @IsEnum(ProductCondition, { message: "无效的新旧程度" })
  condition: ProductCondition;

  @IsNumber({}, { message: "运费必须是数字" })
  @Min(0, { message: "运费不能为负数" })
  shippingFee: number;
}
