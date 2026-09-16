import { Type } from "class-transformer";
import {
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from "class-validator";

export class RouteAgentMessageDto {
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  message: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  petId?: number;

  @IsOptional()
  @IsUUID()
  sessionId?: string;
}
