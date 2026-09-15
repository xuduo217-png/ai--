import { IsOptional, IsBoolean } from 'class-validator';
import { Transform } from 'class-transformer';

export class QueryAddressDto {
  @IsOptional()
  @IsBoolean()
  @Transform(({ value }) => value === 'true')
  isDefault?: boolean;
}
