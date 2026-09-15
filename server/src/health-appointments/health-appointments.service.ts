import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In, Not } from 'typeorm';
import {
  HealthAppointment,
  HealthAppointmentStatus,
  HealthAppointmentType,
} from './entities/health-appointment.entity';
import { CreateHealthAppointmentDto } from './dto/create-health-appointment.dto';
import { QueryHealthAppointmentDto } from './dto/query-health-appointment.dto';
import { UpdateHealthAppointmentStatusDto } from './dto/update-health-appointment-status.dto';
import { CompleteAppointmentDto } from './dto/complete-appointment.dto';
import { PaginatedResult } from '../common/dto/pagination.dto';
import { PetsService } from '../pets/pets.service';
import { HospitalsService } from '../hospitals/hospitals.service';
import {
  createBusinessException,
  ErrorCode,
} from '../common/constants/error-codes';

/**
 * 健康预约服务
 * 提供健康预约的完整 CRUD 功能
 * 完成预约时自动更新宠物健康记录
 */
@Injectable()
export class HealthAppointmentsService {
  constructor(
    @InjectRepository(HealthAppointment)
    private healthAppointmentRepository: Repository<HealthAppointment>,
    private petsService: PetsService,
    private hospitalsService: HospitalsService,
  ) {}

  /**
   * 创建健康预约
   * @param dto 创建预约数据
   * @param userId 用户ID
   * @returns 创建的预约
   */
  async create(
    dto: CreateHealthAppointmentDto,
    userId: number,
  ): Promise<HealthAppointment> {
    const { petId, hospitalId, type, appointmentDate, timeSlot, notes } = dto;

    // 1. 验证宠物所有权 (使用 PetsService)
    const pet = await this.petsService.findOne(petId, userId, 'USER');

    // 2. 验证医院是否存在 (使用 HospitalsService)
    const hospital = await this.hospitalsService.findOne(hospitalId);

    // 3. 检查时间段是否已被预约
    const existing = await this.healthAppointmentRepository.findOne({
      where: {
        petId,
        hospitalId,
        appointmentDate: new Date(appointmentDate),
        timeSlot,
        status: Not(
          In([
            HealthAppointmentStatus.CANCELLED,
            HealthAppointmentStatus.COMPLETED,
          ]),
        ) as any,
        deletedAt: null as any,
      },
    });

    if (existing) {
      throw createBusinessException(
        ErrorCode.APPOINTMENT_CONFLICT,
        '该时间段已被预约，请选择其他时间',
      );
    }

    // 4. 创建预约
    const appointment = this.healthAppointmentRepository.create({
      petId,
      hospitalId,
      userId,
      type,
      appointmentDate: new Date(appointmentDate),
      timeSlot,
      notes,
      status: HealthAppointmentStatus.PENDING,
    });

    const saved = await this.healthAppointmentRepository.save(appointment);

    return this.findOne(saved.id);
  }

  /**
   * 查询健康预约列表
   * @param query 查询参数
   * @param userId 用户ID（可选，用于权限过滤）
   * @param userRole 用户角色（可选）
   * @returns 分页结果
   */
  async findAll(
    query: QueryHealthAppointmentDto,
    userId?: number,
    userRole?: string,
  ): Promise<PaginatedResult<HealthAppointment>> {
    const {
      page = 1,
      pageSize = 10,
      sortOrder = 'DESC',
      sortBy = 'createdAt',
      petId,
      petName,
      ownerPhone,
      type,
      status,
      hospitalId,
    } = query;

    const queryBuilder = this.healthAppointmentRepository
      .createQueryBuilder('appointment')
      .leftJoinAndSelect('appointment.pet', 'pet')
      .leftJoinAndSelect('appointment.hospital', 'hospital')
      .leftJoinAndSelect('appointment.user', 'user')
      .leftJoinAndSelect('appointment.doctor', 'doctor')
      .where('appointment.deletedAt IS NULL');

    // 普通用户只能查看自己的预约
    if (userRole === 'USER' && userId) {
      queryBuilder.andWhere('appointment.userId = :userId', { userId });
    }

    if (petId) {
      queryBuilder.andWhere('appointment.petId = :petId', { petId });
    }

    // 宠物名称模糊搜索
    if (petName) {
      queryBuilder.andWhere('pet.name LIKE :petName', {
        petName: `%${petName}%`,
      });
    }

    // 主人手机号精确匹配
    if (ownerPhone) {
      queryBuilder.andWhere('user.phone = :ownerPhone', { ownerPhone });
    }

    if (type) {
      queryBuilder.andWhere('appointment.type = :type', { type });
    }

    // 处理状态筛选（支持单个状态、状态数组、逗号分隔字符串）
    if (status) {
      if (Array.isArray(status)) {
        // 如果是数组，使用 In 查询
        queryBuilder.andWhere('appointment.status IN (:...status)', {
          status,
        });
      } else if (typeof status === 'string' && status.includes(',')) {
        // 如果是逗号分隔的字符串，拆分为数组后使用 In 查询
        const statusArray = status.split(',').map((s) => s.trim());
        queryBuilder.andWhere('appointment.status IN (:...status)', {
          status: statusArray,
        });
      } else {
        // 如果是单个值，使用等值查询
        queryBuilder.andWhere('appointment.status = :status', { status });
      }
    }

    if (hospitalId) {
      queryBuilder.andWhere('appointment.hospitalId = :hospitalId', {
        hospitalId,
      });
    }

    queryBuilder
      .orderBy(`appointment.${sortBy}`, sortOrder)
      .skip((page - 1) * pageSize)
      .take(pageSize);

    const [data, total] = await queryBuilder.getManyAndCount();

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 查询单个健康预约详情
   * @param id 预约ID
   * @param userId 用户ID（用于权限验证）
   * @returns 预约详情
   */
  async findOne(id: number, userId?: number): Promise<HealthAppointment> {
    const appointment = await this.healthAppointmentRepository.findOne({
      where: { id, deletedAt: null as any },
      relations: ['pet', 'hospital', 'user', 'doctor'],
    });

    if (!appointment) {
      throw new NotFoundException('预约不存在');
    }

    // 验证权限：只能查看自己的预约
    if (userId && appointment.userId !== userId) {
      throw createBusinessException(
        ErrorCode.BUSINESS_PERMISSION_DENIED,
        '无权操作此预约',
      );
    }

    return appointment;
  }

  /**
   * 更新预约状态
   * @param id 预约ID
   * @param dto 状态更新数据
   * @returns 更新后的预约
   */
  async updateStatus(
    id: number,
    dto: UpdateHealthAppointmentStatusDto,
  ): Promise<HealthAppointment> {
    const appointment = await this.findOne(id);

    appointment.status = dto.status;

    // 如果提供了医生ID，更新医生信息
    if (dto.doctorId) {
      appointment.doctorId = dto.doctorId;
    }

    const updated = await this.healthAppointmentRepository.save(appointment);

    // 如果状态为已完成，更新宠物健康记录
    if (dto.status === HealthAppointmentStatus.COMPLETED) {
      await this.updatePetHealthRecords(appointment);
    }

    return this.findOne(updated.id);
  }

  /**
   * 取消预约
   * @param id 预约ID
   * @param userId 用户ID（可选，管理员可为空）
   * @returns 取消后的预约
   */
  async cancel(id: number, userId?: number): Promise<HealthAppointment> {
    const appointment = userId
      ? await this.findOne(id, userId)
      : await this.findOne(id);

    if (appointment.status === HealthAppointmentStatus.COMPLETED) {
      throw createBusinessException(
        ErrorCode.APPOINTMENT_CANNOT_CANCEL,
        '无法取消已完成的预约',
      );
    }

    appointment.status = HealthAppointmentStatus.CANCELLED;
    return this.healthAppointmentRepository.save(appointment);
  }

  /**
   * 删除预约（软删除）
   * @param id 预约ID
   * @param userId 用户ID
   */
  async remove(id: number, userId: number): Promise<void> {
    const appointment = await this.findOne(id, userId);

    if (appointment.status === HealthAppointmentStatus.CONFIRMED) {
      throw createBusinessException(
        ErrorCode.APPOINTMENT_CANNOT_MODIFY,
        '无法删除已确认的预约',
      );
    }

    await this.healthAppointmentRepository.softRemove(appointment);
  }

  /**
   * 更新宠物健康记录
   * 完成预约时自动调用，更新宠物的健康统计字段
   * @param appointment 预约记录
   */
  private async updatePetHealthRecords(
    appointment: HealthAppointment,
  ): Promise<void> {
    // 使用 PetsService 的方法更新健康记录
    await this.petsService.updateHealthRecord(
      appointment.petId,
      appointment.type,
    );
  }

  /**
   * 完成健康预约
   * 标记预约为已完成，并可选地更新宠物的下次预约时间
   * @param id 预约ID
   * @param dto 完成预约数据（包含下次预约日期和备注）
   * @returns 更新后的预约
   */
  async completeAppointment(
    id: number,
    dto: CompleteAppointmentDto,
  ): Promise<HealthAppointment> {
    // 1. 查询预约记录（关联 pet）
    const appointment = await this.healthAppointmentRepository.findOne({
      where: { id, deletedAt: null as any },
      relations: ['pet', 'doctor'],
    });

    if (!appointment) {
      throw new NotFoundException('预约不存在');
    }

    // 2. 更新预约状态为已完成
    appointment.status = HealthAppointmentStatus.COMPLETED;

    // 3. 更新操作内容和详情
    if (dto.operationContent) {
      appointment.operationContent = dto.operationContent;
    }
    if (dto.detailContent) {
      appointment.detailContent = dto.detailContent;
    }
    if (dto.notes) {
      appointment.notes = dto.notes;
    }

    // 4. 如果提供了下次预约日期，更新宠物表
    if (dto.nextAppointmentDate) {
      await this.petsService.updateHealthRecordWithNextDate(
        appointment.petId,
        appointment.type,
        new Date(dto.nextAppointmentDate),
        appointment.appointmentDate,
      );
    } else {
      // 如果没有提供下次预约日期，仍然需要更新上次时间和次数
      await this.updatePetHealthRecords(appointment);
    }

    // 5. 保存预约更新
    const updated = await this.healthAppointmentRepository.save(appointment);

    // 6. 返回完整的预约对象（包含关联数据）
    return this.findOne(updated.id);
  }
}
