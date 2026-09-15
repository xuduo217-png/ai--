import { Controller, Post, Get, Body, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { DoctorsService } from './doctors.service';
import { DoctorLoginDto } from './dto/doctor-login.dto';
import { Doctor } from './entities/doctor.entity';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

/**
 * 医生认证控制器
 * 处理医生登录和获取资料等认证相关功能
 */
@Controller('doctors-auth')
export class DoctorsAuthController {
  constructor(
    private doctorsService: DoctorsService,
    private jwtService: JwtService,
  ) {}

  /**
   * 医生登录
   * 验证用户名和密码，返回 JWT token
   */
  @Post('login')
  @HttpCode(HttpStatus.OK)
  async login(@Body() loginDto: DoctorLoginDto) {
    // 验证医生账号
    const doctor = await this.doctorsService.validateDoctor(
      loginDto.username,
      loginDto.password,
    );

    // 生成 JWT token
    const payload = {
      sub: doctor.id,
      username: doctor.username,
      role: 'DOCTOR',
      type: 'doctor', // 标识这是医生 token
    };

    const access_token = this.jwtService.sign(payload);

    return {
      success: true,
      message: '登录成功',
      data: {
        access_token,
        token_type: 'Bearer',
        doctor: {
          id: doctor.id,
          name: doctor.name,
          username: doctor.username,
          phone: doctor.phone,
          avatar: doctor.avatar,
          specialty: doctor.specialty,
          isGoldDoctor: doctor.isGoldDoctor,
          hospital: doctor.hospital,
          department: doctor.department,
        },
      },
    };
  }

  /**
   * 获取当前医生资料
   * 需要认证
   */
  @Get('profile')
  @UseGuards(JwtAuthGuard)
  async getProfile(@CurrentUser() doctor: Doctor) {
    // 从数据库重新获取完整的医生信息（包含动态计算的统计数据）
    const fullDoctor = await this.doctorsService.findOneWithStats(doctor.id);

    return {
      success: true,
      message: '获取成功',
      data: fullDoctor,
    };
  }
}
