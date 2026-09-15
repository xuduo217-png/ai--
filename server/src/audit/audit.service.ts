import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuditLog, AuditAction } from './entities/audit-log.entity';
import { QueryAuditLogDto } from './dto/query-audit-log.dto';
import { PaginatedResult } from '../common/dto/pagination.dto';

@Injectable()
export class AuditService {
  constructor(
    @InjectRepository(AuditLog)
    private auditLogRepository: Repository<AuditLog>,
  ) {}

  async createLog(
    userId: number,
    targetUserId: number,
    action: AuditAction,
    oldValues: Record<string, any>,
    newValues: Record<string, any>,
    ipAddress: string,
  ): Promise<AuditLog> {
    const auditLog = this.auditLogRepository.create({
      userId,
      targetUserId,
      action,
      oldValues,
      newValues,
      ipAddress,
    });
    return this.auditLogRepository.save(auditLog);
  }

  async findAll(query: QueryAuditLogDto): Promise<PaginatedResult<AuditLog>> {
    const {
      page,
      pageSize,
      sortOrder,
      sortBy,
      userId,
      targetUserId,
      action,
      startDate,
      endDate,
      ipAddress,
    } = query;

    const queryBuilder = this.auditLogRepository.createQueryBuilder('auditLog');

    // 应用筛选条件
    if (userId) {
      queryBuilder.andWhere('auditLog.userId = :userId', { userId });
    }

    if (targetUserId) {
      queryBuilder.andWhere('auditLog.targetUserId = :targetUserId', {
        targetUserId,
      });
    }

    if (action) {
      queryBuilder.andWhere('auditLog.action = :action', { action });
    }

    if (ipAddress) {
      queryBuilder.andWhere('auditLog.ipAddress = :ipAddress', { ipAddress });
    }

    if (startDate) {
      queryBuilder.andWhere('auditLog.createdAt >= :startDate', {
        startDate: new Date(startDate),
      });
    }

    if (endDate) {
      queryBuilder.andWhere('auditLog.createdAt <= :endDate', {
        endDate: new Date(endDate + ' 23:59:59'),
      });
    }

    // 应用排序
    const order = sortOrder === 'ASC' ? 'ASC' : 'DESC';
    queryBuilder.orderBy(`auditLog.${sortBy}`, order);

    // 应用分页
    const skip = (page - 1) * pageSize;
    queryBuilder.skip(skip).take(pageSize);

    // 关联用户信息
    queryBuilder.leftJoinAndSelect('auditLog.user', 'user');
    queryBuilder.leftJoinAndSelect('auditLog.targetUser', 'targetUser');

    const [data, total] = await queryBuilder.getManyAndCount();

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  // 保留旧方法以保持向后兼容
  async findByTargetUserId(
    targetUserId: number,
    pageSize = 50,
  ): Promise<AuditLog[]> {
    return this.auditLogRepository.find({
      where: { targetUserId },
      order: { createdAt: 'DESC' },
      take: pageSize,
    });
  }

  async findByAction(action: AuditAction, pageSize = 50): Promise<AuditLog[]> {
    return this.auditLogRepository.find({
      where: { action },
      order: { createdAt: 'DESC' },
      take: pageSize,
    });
  }
}
