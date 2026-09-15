import { PartialType } from '@nestjs/mapped-types';
import { CreateServiceItemDto } from './create-service-item.dto';

/**
 * 更新收费项 DTO
 * 所有字段都是可选的，支持部分更新
 */
export class UpdateServiceItemDto extends PartialType(CreateServiceItemDto) {}
