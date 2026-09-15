import { PartialType } from '@nestjs/swagger';
import { CreateLogisticsDto } from './create-logistics.dto';

/**
 * 更新物流公司 DTO
 */
export class UpdateLogisticsDto extends PartialType(CreateLogisticsDto) {}
