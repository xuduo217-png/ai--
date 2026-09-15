import {
  Controller,
  Get,
  Query,
  UseGuards,
  Param,
  ParseIntPipe,
} from '@nestjs/common';
import { AuditService } from './audit.service';
import { QueryAuditLogDto } from './dto/query-audit-log.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';
import { AuditAction } from './entities/audit-log.entity';

@ApiTags('audit')
@ApiBearerAuth()
@Controller('audit')
@UseGuards(JwtAuthGuard)
export class AuditController {
  constructor(private readonly auditService: AuditService) {}

  @Get('logs')
  @ApiOperation({ summary: '查询审计日志' })
  @ApiQuery({ name: 'page', required: false, example: 1 })
  @ApiQuery({ name: 'limit', required: false, example: 10 })
  @ApiQuery({ name: 'userId', required: false })
  @ApiQuery({ name: 'targetUserId', required: false })
  @ApiQuery({
    name: 'action',
    required: false,
    enum: [
      'user_created',
      'user_updated',
      'user_deleted',
      'role_changed',
      'password_reset',
      'password_changed',
    ],
  })
  @ApiQuery({ name: 'startDate', required: false })
  @ApiQuery({ name: 'endDate', required: false })
  async getAllLogs(@Query() query: QueryAuditLogDto) {
    return this.auditService.findAll(query);
  }

  @Get('logs/user/:targetUserId')
  @ApiOperation({ summary: '查询指定用户的审计日志' })
  async getUserLogs(
    @Param('targetUserId', ParseIntPipe) targetUserId: number,
    @Query() query: QueryAuditLogDto,
  ) {
    const modifiedQuery = { ...query, targetUserId };
    return this.auditService.findAll(modifiedQuery);
  }

  @Get('logs/action/:action')
  @ApiOperation({ summary: '查询指定操作的审计日志' })
  async getActionLogs(
    @Param('action') action: AuditAction,
    @Query() query: QueryAuditLogDto,
  ) {
    const modifiedQuery = { ...query, action };
    return this.auditService.findAll(modifiedQuery);
  }
}
