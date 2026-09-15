import { Type } from "class-transformer";
import { ApiProperty } from "@nestjs/swagger";
import { IsNumber, Min } from "class-validator";

export class CreateCharityDonationPaymentDto {
  @ApiProperty({ description: "捐款金额", example: 20 })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;
}
