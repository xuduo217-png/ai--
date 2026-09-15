import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  ValidateIf,
} from "class-validator";
import { ApiProperty } from "@nestjs/swagger";

export class ClaimCouponDto {
  @ApiProperty({ description: "优惠券ID", example: 1, required: false })
  @ValidateIf((_, value) => typeof value !== "undefined")
  @IsInt()
  @IsOptional()
  couponId?: number;

  @ApiProperty({
    description: "扫码领取码",
    example: "CLAIM_D37EBD",
    required: false,
  })
  @ValidateIf((object) => !object.couponId)
  @IsString()
  @IsNotEmpty()
  claimCode?: string;
}
