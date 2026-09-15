import {
  ArrayUnique,
  IsArray,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { MallHomepageBannerActionType } from '../shop.service';

export class UpdateMallHotProductsDto {
  @IsArray()
  @ArrayUnique()
  @Type(() => Number)
  @IsInt({ each: true })
  @Min(1, { each: true })
  productIds: number[];
}

export class MallHomepageBannerDto {
  @IsOptional()
  @IsString()
  id?: string;

  @IsString()
  imageUrl: string;

  @IsOptional()
  @IsString()
  link?: string;

  @IsOptional()
  @IsEnum(MallHomepageBannerActionType)
  actionType?: MallHomepageBannerActionType;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  productId?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  sortOrder?: number;
}

export class UpdateMallHomepageBannersDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => MallHomepageBannerDto)
  banners: MallHomepageBannerDto[];
}
