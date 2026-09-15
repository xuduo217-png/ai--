import { ApiProperty, ApiPropertyOptional } from "@nestjs/swagger";
import { IsEnum, IsOptional, IsString, MaxLength } from "class-validator";
import {
  ReportAction,
  ReportStatus,
} from "../entities/ugc-report.entity";

export class UpdateReportStatusDto {
  @ApiProperty({ description: "处理状态", enum: ReportStatus })
  @IsEnum(ReportStatus, { message: "处理状态无效" })
  status: ReportStatus;

  @ApiPropertyOptional({ description: "处理备注", maxLength: 500 })
  @IsOptional()
  @IsString({ message: "处理备注必须是字符串" })
  @MaxLength(500, { message: "处理备注最多500字符" })
  remark?: string;
}

export class HandleReportActionDto {
  @ApiProperty({ description: "处理动作", enum: ReportAction })
  @IsEnum(ReportAction, { message: "处理动作无效" })
  action: ReportAction;

  @ApiPropertyOptional({ description: "处理备注", maxLength: 500 })
  @IsOptional()
  @IsString({ message: "处理备注必须是字符串" })
  @MaxLength(500, { message: "处理备注最多500字符" })
  remark?: string;
}
