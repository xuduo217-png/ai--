import { PartialType } from '@nestjs/swagger';
import { CreateActivityDto } from './create-activity.dto';

/**
 * 更新活动 DTO
 * 所有字段都变为可选
 */
export class UpdateActivityDto extends PartialType(CreateActivityDto) {}
