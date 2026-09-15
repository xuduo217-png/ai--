import {
  IsOptional,
  IsString,
  IsNumber,
  Min,
  IsEnum,
  MaxLength,
  IsBoolean,
  IsArray,
  ValidateNested,
} from 'class-validator';
import { ProductCategory } from '../entities/product.entity';
import { Type } from 'class-transformer';
import { UpdateProductSkuDto } from './update-product-sku.dto';

export class UpdateProductDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  price?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  stock?: number;

  @IsOptional()
  @IsString()
  image?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  images?: string[];

  @IsOptional()
  @IsNumber()
  @Min(0)
  categoryId?: number;

  @IsOptional()
  @IsEnum(ProductCategory)
  category?: ProductCategory;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsBoolean()
  isVirtual?: boolean;

  @IsOptional()
  @IsBoolean()
  hasSku?: boolean;

  @IsOptional()
  @IsString()
  publishSource?: string;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => UpdateProductSkuDto)
  skus?: UpdateProductSkuDto[];
}
