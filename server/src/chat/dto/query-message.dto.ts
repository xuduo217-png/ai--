import { IsOptional, IsString } from 'class-validator';
import { Type } from 'class-transformer';
import { PaginationDto } from '../../common/dto/pagination.dto';

export class QueryMessageDto extends PaginationDto {
  @IsOptional()
  @IsString()
  conversationId?: string;

  @IsOptional()
  @Type(() => Number)
  senderId?: number;

  @IsOptional()
  @Type(() => Number)
  receiverId?: number;

  @IsOptional()
  @IsString()
  sortBy?: 'createdAt' | 'updatedAt' = 'createdAt';
}
