import { IsArray, ValidateNested, IsNotEmpty } from 'class-validator';
import { Type } from 'class-transformer';
import { CreateServiceItemDto } from './create-service-item.dto';

/**
 * 批量创建收费项 DTO
 * 用于创建医生时同时创建多个收费项
 */
export class BatchCreateServiceItemsDto {
  /**
   * 收费项列表
   */
  @IsArray()
  @ValidateNested({ each: true })
  @IsNotEmpty({ message: '至少需要配置一个收费项' })
  @Type(() => CreateServiceItemDto)
  serviceItems: CreateServiceItemDto[];
}
