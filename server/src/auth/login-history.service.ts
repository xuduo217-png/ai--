import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  LoginHistory,
  LoginMethod,
  LoginStatus,
} from './entities/login-history.entity';

@Injectable()
export class LoginHistoryService {
  constructor(
    @InjectRepository(LoginHistory)
    private loginHistoryRepository: Repository<LoginHistory>,
  ) {}

  async createLoginHistory(
    userId: number,
    ipAddress: string,
    userAgent: string,
    loginMethod: LoginMethod,
    status: LoginStatus,
    failureReason?: string,
  ): Promise<LoginHistory> {
    const loginHistory = this.loginHistoryRepository.create({
      userId,
      ipAddress,
      userAgent,
      loginMethod,
      status,
      failureReason,
    });
    return this.loginHistoryRepository.save(loginHistory);
  }

  async getUserLoginHistory(
    userId: number,
    pageSize = 20,
  ): Promise<LoginHistory[]> {
    return this.loginHistoryRepository.find({
      where: { userId },
      order: { loginAt: 'DESC' },
      take: pageSize,
    });
  }

  async getRecentFailedLogins(phone: string, minutes = 30): Promise<number> {
    const recentTime = new Date(Date.now() - minutes * 60 * 1000);
    // This would need User entity join, simplified for now
    return this.loginHistoryRepository.count({
      where: {
        status: LoginStatus.FAILED,
        loginAt: { $gte: recentTime } as any,
      } as any,
    });
  }
}
