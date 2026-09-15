import { IsObject, IsNotEmpty, IsString, IsOptional } from 'class-validator';

/**
 * 更新系统配置 DTO
 */
export class UpdateSystemConfigDto {
  @IsObject()
  @IsNotEmpty()
  configValue: Record<string, any>;

  @IsString()
  @IsOptional()
  description?: string;
}
