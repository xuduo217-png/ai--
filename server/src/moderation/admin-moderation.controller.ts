import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  Request,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiParam, ApiTags } from "@nestjs/swagger";
import { Roles } from "../auth/decorators/roles.decorator";
import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";
import { RolesGuard } from "../auth/guards/roles.guard";
import { UserRole } from "../users/entities/user.entity";
import { HandleReportActionDto, UpdateReportStatusDto } from "./dto/handle-report.dto";
import { QueryReportsDto } from "./dto/query-reports.dto";
import { ModerationService } from "./moderation.service";

@ApiTags("Admin UGC 举报处理")
@ApiBearerAuth()
@Controller("admin/moderation")
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN, UserRole.STAFF)
export class AdminModerationController {
  constructor(private readonly moderationService: ModerationService) {}

  @Get("reports")
  @ApiOperation({ summary: "获取举报列表" })
  async getReports(@Query() query: QueryReportsDto) {
    return this.moderationService.findReports(query);
  }

  @Get("reports/:id")
  @ApiOperation({ summary: "获取举报详情" })
  @ApiParam({ name: "id", description: "举报ID" })
  async getReportDetail(@Param("id", ParseIntPipe) id: number) {
    return this.moderationService.findReportDetail(id);
  }

  @Patch("reports/:id/status")
  @ApiOperation({ summary: "更新举报处理状态" })
  async updateReportStatus(
    @Param("id", ParseIntPipe) id: number,
    @Request() req,
    @Body() dto: UpdateReportStatusDto,
  ) {
    return this.moderationService.updateReportStatus(id, req.user.id, dto);
  }

  @Post("reports/:id/actions")
  @ApiOperation({ summary: "执行举报处理动作" })
  async handleReportAction(
    @Param("id", ParseIntPipe) id: number,
    @Request() req,
    @Body() dto: HandleReportActionDto,
  ) {
    return this.moderationService.handleReportAction(id, req.user.id, dto);
  }
}
