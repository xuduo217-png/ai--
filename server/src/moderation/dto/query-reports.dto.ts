import { ApiPropertyOptional } from "@nestjs/swagger";
import { Type } from "class-transformer";
import { IsEnum, IsInt, IsOptional, IsString, Min } from "class-validator";
import {
  ReportReason,
  ReportStatus,
  ReportTargetType,
} from "../entities/ugc-report.entity";

export class QueryReportsDto {
  @ApiPropertyOptional({ description: "页码", example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: "页码必须是整数" })
  @Min(1, { message: "页码最小为1" })
  page?: number = 1;

  @ApiPropertyOptional({ description: "每页数量", example: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: "每页数量必须是整数" })
  @Min(1, { message: "每页数量最小为1" })
  pageSize?: number = 20;

  @ApiPropertyOptional({ description: "处理状态", enum: ReportStatus })
  @IsOptional()
  @IsEnum(ReportStatus, { message: "处理状态无效" })
  status?: ReportStatus;

  @ApiPropertyOptional({ description: "目标类型", enum: ReportTargetType })
  @IsOptional()
  @IsEnum(ReportTargetType, { message: "目标类型无效" })
  targetType?: ReportTargetType;

  @ApiPropertyOptional({ description: "举报原因", enum: ReportReason })
  @IsOptional()
  @IsEnum(ReportReason, { message: "举报原因无效" })
  reason?: ReportReason;

  @ApiPropertyOptional({ description: "开始时间" })
  @IsOptional()
  @IsString({ message: "开始时间必须是字符串" })
  startTime?: string;

  @ApiPropertyOptional({ description: "结束时间" })
  @IsOptional()
  @IsString({ message: "结束时间必须是字符串" })
  endTime?: string;
}
