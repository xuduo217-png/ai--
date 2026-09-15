import { IsString, IsNotEmpty, IsOptional, IsObject } from 'class-validator';

/**
 * 创建系统配置 DTO
 */
export class CreateSystemConfigDto {
  @IsString()
  @IsNotEmpty()
  configKey: string;

  @IsObject()
  @IsNotEmpty()
  configValue: Record<string, any>;

  @IsString()
  @IsOptional()
  description?: string;
}
