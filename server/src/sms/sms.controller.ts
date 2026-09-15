import {
  Controller,
  Post,
  Get,
  Body,
  Query,
  UseGuards,
  UsePipes,
  ValidationPipe,
} from '@nestjs/common';
import { SmsService } from './sms.service';
import { SendSmsDto } from './dto/send-sms.dto';
import { QuerySmsRecordDto } from './dto/query-sms-record.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';
import { UserRole } from '../users/entities/user.entity';

@ApiTags('sms')
@ApiBearerAuth()
@Controller('sms')
@UseGuards(JwtAuthGuard)
export class SmsController {
  constructor(private readonly smsService: SmsService) {}

  @Post('send-code')
  @UsePipes(
    new ValidationPipe({
      transform: true,
      whitelist: true,
    }),
  )
  @ApiOperation({ summary: '发送短信验证码' })
  async sendCode(@Body() sendSmsDto: SendSmsDto) {
    const { phone, type } = sendSmsDto;

    // 验证手机号格式
    if (!this.smsService.validatePhone(phone)) {
      return {
        success: false,
        message: '手机号格式不正确',
      };
    }

    try {
      const result = await this.smsService.sendVerificationCode(phone, type);
      return {
        success: true,
        message: '验证码已发送',
        expiresIn: result.expiresIn,
      };
    } catch (error) {
      return {
        success: false,
        message: error.message || '验证码发送失败',
      };
    }
  }

  @Get('records')
  @UseGuards(RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN)
  @ApiOperation({ summary: '获取短信记录列表（管理员）' })
  @ApiQuery({ name: 'page', required: false, example: 1 })
  @ApiQuery({ name: 'limit', required: false, example: 10 })
  @ApiQuery({ name: 'phone', required: false })
  @ApiQuery({
    name: 'type',
    required: false,
    enum: ['register', 'reset_password', 'login'],
  })
  @ApiQuery({
    name: 'status',
    required: false,
    enum: ['pending', 'sent', 'failed', 'expired'],
  })
  async getSmsRecords(@Query() query: QuerySmsRecordDto) {
    return this.smsService.getSmsRecords(query);
  }

  @Get('stats')
  @UseGuards(RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN)
  @ApiOperation({ summary: '获取短信统计（管理员）' })
  @ApiQuery({ name: 'phone', required: false })
  @ApiQuery({ name: 'startDate', required: false })
  @ApiQuery({ name: 'endDate', required: false })
  async getSmsStats(
    @Query('phone') phone?: string,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
  ) {
    const start = startDate ? new Date(startDate) : undefined;
    const end = endDate ? new Date(endDate) : undefined;

    return this.smsService.getSmsStats(phone, start, end);
  }
}
