import { ApiProperty, ApiPropertyOptional } from "@nestjs/swagger";
import { IsEnum, IsNotEmpty, IsOptional, IsString, MaxLength } from "class-validator";
import {
  ReportReason,
  ReportTargetType,
} from "../entities/ugc-report.entity";

export class CreateReportDto {
  @ApiProperty({ description: "举报目标类型", enum: ReportTargetType })
  @IsEnum(ReportTargetType, { message: "举报目标类型无效" })
  targetType: ReportTargetType;

  @ApiProperty({ description: "举报目标ID", example: "12" })
  @IsNotEmpty({ message: "举报目标ID不能为空" })
  @IsString({ message: "举报目标ID必须是字符串" })
  @MaxLength(64, { message: "举报目标ID过长" })
  targetId: string | number;

  @ApiProperty({ description: "举报原因", enum: ReportReason })
  @IsEnum(ReportReason, { message: "举报原因无效" })
  reason: ReportReason;

  @ApiPropertyOptional({ description: "补充说明", maxLength: 500 })
  @IsOptional()
  @IsString({ message: "补充说明必须是字符串" })
  @MaxLength(500, { message: "补充说明最多500字符" })
  description?: string;
}
