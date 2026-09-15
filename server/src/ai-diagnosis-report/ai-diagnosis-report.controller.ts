import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { AiDiagnosisReportService } from './ai-diagnosis-report.service';
import { CreateReportDto, QueryReportsDto } from './dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

/**
 * AI 问诊报告控制器
 */
@ApiTags('AI 问诊报告')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('ai-diagnosis-reports')
export class AiDiagnosisReportController {
  constructor(private readonly reportService: AiDiagnosisReportService) {}

  /**
   * 创建 AI 问诊报告
   */
  @Post()
  @Roles('USER')
  @ApiOperation({ summary: '创建 AI 问诊报告' })
  @ApiResponse({ status: 201, description: '报告创建成功' })
  async create(@CurrentUser() user, @Body() createReportDto: CreateReportDto) {
    const report = await this.reportService.create(user.id, createReportDto);
    return {
      code: 0,
      data: report,
      message: 'AI 问诊报告创建成功，正在生成诊断结果',
    };
  }

  /**
   * 获取报告列表
   */
  @Get()
  @Roles('SUPER_ADMIN', 'DOCTOR', 'USER')
  @ApiOperation({ summary: '获取报告列表' })
  @ApiResponse({ status: 200, description: '获取成功' })
  async findAll(@CurrentUser() user, @Query() queryDto: QueryReportsDto) {
    const result = await this.reportService.findAll(
      queryDto,
      user.id,
      user.role,
    );
    return {
      code: 0,
      data: result.data,
      pagination: {
        total: result.total,
        page: result.page,
        pageSize: result.pageSize,
        totalPages: Math.ceil(result.total / result.pageSize),
      },
      message: '获取报告列表成功',
    };
  }

  /**
   * 获取报告详情
   */
  @Get(':id')
  @Roles('SUPER_ADMIN', 'DOCTOR', 'USER')
  @ApiOperation({ summary: '获取报告详情' })
  @ApiResponse({ status: 200, description: '获取成功' })
  async findOne(@Param('id') id: string, @CurrentUser() user) {
    const report = await this.reportService.findOne(+id, user.id, user.role);
    return {
      code: 0,
      data: report,
    };
  }

  /**
   * 删除报告
   */
  @Delete(':id')
  @Roles('SUPER_ADMIN')
  @ApiOperation({ summary: '删除报告' })
  @ApiResponse({ status: 200, description: '删除成功' })
  async remove(@Param('id') id: string, @CurrentUser() user) {
    const result = await this.reportService.remove(+id, user.role);
    return {
      code: 0,
      ...result,
    };
  }
}
