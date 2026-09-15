import { IsEnum, IsInt, IsOptional, IsString, IsJSON, Min, IsBoolean } from 'class-validator';
import { NotificationType, ActionType } from '../entities/notification.entity';

/**
 * 查询通知列表 DTO
 */
export class QueryNotificationsDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  page: number = 1;

  @IsOptional()
  @IsInt()
  @Min(1)
  pageSize: number = 20;

  @IsOptional()
  @IsEnum(NotificationType)
  type?: NotificationType;
}

/**
 * 获取未读数量响应 DTO
 */
export class UnreadCountResponseDto {
  count: number;
}

/**
 * 标记已读响应 DTO
 */
export class MarkAsReadResponseDto {
  success: boolean;
}

/**
 * 全部标记已读响应 DTO
 */
export class MarkAllAsReadResponseDto {
  success: boolean;
  updatedCount: number;
}

/**
 * 创建通知 DTO（内部使用）
 */
export class CreateNotificationDto {
  @IsInt()
  userId: number;

  @IsEnum(NotificationType)
  type: NotificationType;

  @IsString()
  title: string;

  @IsString()
  content: string;

  @IsOptional()
  @IsEnum(ActionType)
  actionType?: ActionType;

  @IsOptional()
  actionData?: Record<string, any>;

  @IsOptional()
  @IsInt()
  @Min(0)
  priority?: number;
}
