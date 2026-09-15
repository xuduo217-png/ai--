import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Not, Between } from 'typeorm';
import { Appointment, AppointmentStatus } from './entities/appointment.entity';
import { CreateAppointmentDto } from './dto/create-appointment.dto';
import { UpdateAppointmentDto } from './dto/update-appointment.dto';
import { QueryAppointmentDto } from './dto/query-appointment.dto';
import { ConfirmAppointmentDto } from './dto/confirm-appointment.dto';
import { PaginatedResult } from '../common/dto/pagination.dto';
import { NotificationSenderService } from '../notifications/notification-sender.service';

@Injectable()
export class AppointmentsService {
  constructor(
    @InjectRepository(Appointment)
    private appointmentRepository: Repository<Appointment>,
    private readonly notificationSender: NotificationSenderService,
  ) {}

  async create(
    createAppointmentDto: CreateAppointmentDto,
    userId: number,
  ): Promise<Appointment> {
    const { petId, hospitalId, appointmentTime, type, symptoms } =
      createAppointmentDto;

    const appointment = this.appointmentRepository.create({
      petId,
      hospitalId,
      userId,
      appointmentTime: new Date(appointmentTime),
      type,
      symptoms,
      status: AppointmentStatus.PENDING,
    });

    const saved = await this.appointmentRepository.save(appointment);

    // 发送预约创建成功通知
    const appointmentWithRelations = await this.findOne(saved.id);
    await this.notificationSender.appointmentCreated(userId, {
      appointmentId: saved.id,
      hospitalName: appointmentWithRelations.hospital?.name,
    });

    return appointmentWithRelations;
  }

  async findAll(
    query: QueryAppointmentDto,
    userId?: number,
    userRole?: string,
  ): Promise<PaginatedResult<Appointment>> {
    const {
      page = 1,
      pageSize = 10,
      sortOrder = 'DESC',
      sortBy = 'createdAt',
      hospitalId,
      doctorId,
      userId: queryUserId,
      petId,
      status,
      type,
      startDate,
      endDate,
      keyword,
    } = query;

    const queryBuilder = this.appointmentRepository
      .createQueryBuilder('appointment')
      .leftJoinAndSelect('appointment.pet', 'pet')
      .leftJoinAndSelect('appointment.doctor', 'doctor')
      .leftJoinAndSelect('appointment.hospital', 'hospital')
      .leftJoinAndSelect('appointment.user', 'user')
      .leftJoinAndSelect('appointment.confirmedBy', 'confirmedBy')
      .where('appointment.deletedAt IS NULL');

    if (userRole === 'USER') {
      queryBuilder.andWhere('appointment.userId = :userId', { userId });
    } else if (userRole === 'DOCTOR') {
      queryBuilder.andWhere('appointment.doctorId = :userId', { userId });
    }

    if (hospitalId) {
      queryBuilder.andWhere('appointment.hospitalId = :hospitalId', {
        hospitalId,
      });
    }

    if (doctorId) {
      queryBuilder.andWhere('appointment.doctorId = :doctorId', { doctorId });
    }

    if (queryUserId) {
      queryBuilder.andWhere('appointment.userId = :queryUserId', {
        queryUserId,
      });
    }

    if (petId) {
      queryBuilder.andWhere('appointment.petId = :petId', { petId });
    }

    if (status) {
      queryBuilder.andWhere('appointment.status = :status', { status });
    }

    if (type) {
      queryBuilder.andWhere('appointment.type = :type', { type });
    }

    if (startDate && endDate) {
      queryBuilder.andWhere(
        'appointment.appointmentTime BETWEEN :startDate AND :endDate',
        {
          startDate: new Date(startDate),
          endDate: new Date(endDate),
        },
      );
    } else if (startDate) {
      queryBuilder.andWhere('appointment.appointmentTime >= :startDate', {
        startDate: new Date(startDate),
      });
    } else if (endDate) {
      queryBuilder.andWhere('appointment.appointmentTime <= :endDate', {
        endDate: new Date(endDate),
      });
    }

    if (keyword) {
      queryBuilder.andWhere(
        '(appointment.symptoms LIKE :keyword OR appointment.diagnosis LIKE :keyword OR appointment.treatment LIKE :keyword)',
        { keyword: `%${keyword}%` },
      );
    }

    const order = sortOrder === 'ASC' ? 'ASC' : 'DESC';
    queryBuilder.orderBy(`appointment.${sortBy}`, order);

    const skip = (page - 1) * pageSize;
    queryBuilder.skip(skip).take(pageSize);

    const [data, total] = await queryBuilder.getManyAndCount();

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  async findOne(
    id: number,
    userId?: number,
    userRole?: string,
  ): Promise<Appointment> {
    const appointment = await this.appointmentRepository.findOne({
      where: { id, deletedAt: null },
      relations: ['pet', 'doctor', 'hospital', 'user', 'confirmedBy'],
    });

    if (!appointment) {
      throw new NotFoundException('预约不存在');
    }

    if (userRole === 'USER' && appointment.userId !== userId) {
      throw new ForbiddenException('无权查看此预约');
    }

    if (userRole === 'DOCTOR' && appointment.doctorId !== userId) {
      throw new ForbiddenException('无权查看此预约');
    }

    return appointment;
  }

  async update(
    id: number,
    updateAppointmentDto: UpdateAppointmentDto,
    userId: number,
    userRole: string,
  ): Promise<Appointment> {
    const appointment = await this.appointmentRepository.findOne({
      where: { id, deletedAt: null },
      relations: ['hospital'],
    });

    if (!appointment) {
      throw new NotFoundException('预约不存在');
    }

    if (userRole === 'USER') {
      if (appointment.userId !== userId) {
        throw new ForbiddenException('无权修改此预约');
      }

      if (
        updateAppointmentDto.status &&
        updateAppointmentDto.status !== AppointmentStatus.CANCELLED
      ) {
        throw new ForbiddenException('用户只能取消预约');
      }
    } else if (userRole === 'DOCTOR') {
      if (appointment.doctorId !== userId) {
        throw new ForbiddenException('无权修改此预约');
      }
    }

    if (updateAppointmentDto.appointmentTime) {
      updateAppointmentDto.appointmentTime = new Date(
        updateAppointmentDto.appointmentTime,
      ) as any;
    }

    if (updateAppointmentDto.nextAppointmentTime) {
      updateAppointmentDto.nextAppointmentTime = new Date(
        updateAppointmentDto.nextAppointmentTime,
      ) as any;
    }

    await this.appointmentRepository.update(id, updateAppointmentDto);
    const updated = await this.findOne(id, userId, userRole);

    // 发送预约取消通知
    if (updateAppointmentDto.status === AppointmentStatus.CANCELLED) {
      await this.notificationSender.appointmentCancelled(userId, {
        appointmentId: id,
        hospitalName: appointment.hospital?.name,
      });
    }

    return updated;
  }

  async remove(id: number, userId: number, userRole: string): Promise<void> {
    const appointment = await this.appointmentRepository.findOne({
      where: { id, deletedAt: null },
    });

    if (!appointment) {
      throw new NotFoundException('预约不存在');
    }

    if (userRole === 'USER' && appointment.userId !== userId) {
      throw new ForbiddenException('无权删除此预约');
    }

    await this.appointmentRepository.softDelete(id);
  }

  async confirmAppointment(
    id: number,
    confirmDto: ConfirmAppointmentDto,
    staffUserId: number,
    userRole: string,
  ): Promise<Appointment> {
    const appointment = await this.appointmentRepository.findOne({
      where: { id, deletedAt: null },
      relations: ['hospital', 'user'],
    });

    if (!appointment) {
      throw new NotFoundException('预约不存在');
    }

    if (
      userRole !== 'SUPER_ADMIN' &&
      userRole !== 'HOSPITAL_ADMIN' &&
      userRole !== 'STAFF'
    ) {
      throw new ForbiddenException('无权确认预约');
    }

    if (appointment.status !== AppointmentStatus.PENDING) {
      throw new BadRequestException('只能确认待确认状态的预约');
    }

    const { doctorId, appointmentTime, symptoms, notes, nextAppointmentTime } =
      confirmDto;

    await this.appointmentRepository.update(id, {
      doctorId,
      appointmentTime: new Date(appointmentTime),
      symptoms: symptoms || appointment.symptoms,
      notes,
      nextAppointmentTime: nextAppointmentTime
        ? new Date(nextAppointmentTime)
        : null,
      status: AppointmentStatus.CONFIRMED,
      confirmedById: staffUserId,
      confirmedAt: new Date(),
    } as any);

    const updated = await this.findOne(id);

    // 发送预约确认通知
    await this.notificationSender.appointmentConfirmed(appointment.userId, {
      appointmentId: id,
      hospitalName: appointment.hospital?.name,
      appointmentTime: new Date(appointmentTime).toLocaleString('zh-CN'),
    });

    return updated;
  }

  async findByDoctor(
    doctorId: number,
    status?: AppointmentStatus,
  ): Promise<Appointment[]> {
    const where: any = { doctorId, deletedAt: null };
    if (status) {
      where.status = status;
    }
    return this.appointmentRepository.find({
      where,
      relations: ['pet', 'user', 'hospital'],
      order: { appointmentTime: 'ASC' },
    });
  }

  async findByUser(userId: number): Promise<Appointment[]> {
    return this.appointmentRepository.find({
      where: { userId, deletedAt: null },
      relations: ['pet', 'doctor', 'hospital'],
      order: { appointmentTime: 'DESC' },
    });
  }

  async findByHospital(
    hospitalId: number,
    status?: AppointmentStatus,
  ): Promise<Appointment[]> {
    const where: any = { hospitalId, deletedAt: null };
    if (status) {
      where.status = status;
    }
    return this.appointmentRepository.find({
      where,
      relations: ['pet', 'user', 'doctor'],
      order: { appointmentTime: 'ASC' },
    });
  }

  async getStatistics(
    userId?: number,
    userRole?: string,
    hospitalId?: number,
  ): Promise<any> {
    const params: any = { deletedAt: null };

    if (userRole === 'USER') {
      params.userId = userId;
    } else if (userRole === 'DOCTOR') {
      params.doctorId = userId;
    } else if (hospitalId) {
      params.hospitalId = hospitalId;
    }

    const total = await this.appointmentRepository.count({ where: params });

    const byStatus = await this.appointmentRepository
      .createQueryBuilder('appointment')
      .select('appointment.status', 'status')
      .addSelect('COUNT(*)', 'count')
      .where(this.buildWhereClause(params))
      .groupBy('appointment.status')
      .getRawMany();

    const byType = await this.appointmentRepository
      .createQueryBuilder('appointment')
      .select('appointment.type', 'type')
      .addSelect('COUNT(*)', 'count')
      .where(this.buildWhereClause(params))
      .groupBy('appointment.type')
      .getRawMany();

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const todayCount = await this.appointmentRepository.count({
      where: {
        ...params,
        appointmentTime: Between(today, tomorrow),
      },
    });

    return {
      total,
      byStatus: byStatus.reduce(
        (acc, item) => ({ ...acc, [item.status]: parseInt(item.count) }),
        {},
      ),
      byType: byType.reduce(
        (acc, item) => ({ ...acc, [item.type]: parseInt(item.count) }),
        {},
      ),
      todayCount,
    };
  }

  private buildWhereClause(params: any): string {
    const conditions = ['appointment.deletedAt IS NULL'];
    Object.keys(params).forEach((key) => {
      if (key !== 'deletedAt') {
        conditions.push(`appointment.${key} = :${key}`);
      }
    });
    return conditions.join(' AND ');
  }
}
