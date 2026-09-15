import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ModuleRef } from '@nestjs/core';
import { EntityManager, Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { Doctor } from './entities/doctor.entity';
import { DoctorServiceItem } from './entities/doctor-service-item.entity';
import { CreateDoctorDto } from './dto/create-doctor.dto';
import { UpdateDoctorDto } from './dto/update-doctor.dto';
import { QueryDoctorDto } from './dto/query-doctor.dto';
import { CreateServiceItemDto } from './dto/create-service-item.dto';
import { UpdateServiceItemDto } from './dto/update-service-item.dto';
import { BatchCreateServiceItemsDto } from './dto/batch-create-service-items.dto';
import { PaginatedResult } from '../common/dto/pagination.dto';

/**
 * 医生服务类
 * 处理医生相关的业务逻辑
 */
@Injectable()
export class DoctorsService {
  private moduleRef: ModuleRef;
  private readonly logger = new Logger(DoctorsService.name);

  constructor(
    @InjectRepository(Doctor)
    private doctorRepository: Repository<Doctor>,
    @InjectRepository(DoctorServiceItem)
    private serviceItemRepository: Repository<DoctorServiceItem>,
  ) {}

  /**
   * 批量查询医生的已支付咨询订单数。
   */
  private async getPaidConsultationCounts(
    doctorIds: number[],
    manager: EntityManager = this.doctorRepository.manager,
  ): Promise<Map<number, number>> {
    const uniqueDoctorIds = [...new Set(doctorIds.filter((id) => id > 0))];
    if (uniqueDoctorIds.length === 0) return new Map();

    const rows = await manager
      .createQueryBuilder()
      .select('consultationOrder.doctorId', 'doctorId')
      .addSelect('COUNT(consultationOrder.id)', 'count')
      .from('chat_orders', 'consultationOrder')
      .where('consultationOrder.doctorId IN (:...doctorIds)', {
        doctorIds: uniqueDoctorIds,
      })
      .andWhere('consultationOrder.status = :paidStatus', {
        paidStatus: 'PAID',
      })
      .groupBy('consultationOrder.doctorId')
      .getRawMany<{ doctorId: string; count: string }>();

    return new Map(
      rows.map((row) => [
        Number(row.doctorId),
        Number.parseInt(row.count || '0', 10),
      ]),
    );
  }

  private async populateConsultationCounts(
    doctors: Doctor[],
    manager?: EntityManager,
  ): Promise<void> {
    const counts = await this.getPaidConsultationCounts(
      doctors.map((doctor) => doctor.id),
      manager,
    );
    doctors.forEach((doctor) => {
      doctor.consultationCount = counts.get(doctor.id) ?? 0;
    });
  }

  /**
   * 设置 ModuleRef（用于延迟获取 ChatGateway）
   * @param ref ModuleRef 实例
   */
  setModuleRef(ref: ModuleRef) {
    this.moduleRef = ref;
  }

  /**
   * 创建医生
   * 包含账号验证、密码加密、关联验证等
   */
  async create(createDoctorDto: CreateDoctorDto): Promise<Doctor> {
    // 验证用户名是否已存在
    const existingByUsername = await this.doctorRepository.findOne({
      where: { username: createDoctorDto.username },
    });
    if (existingByUsername) {
      throw new BadRequestException('用户名已存在');
    }

    // 验证手机号是否已存在
    const existingByPhone = await this.doctorRepository.findOne({
      where: { phone: createDoctorDto.phone },
    });
    if (existingByPhone) {
      throw new BadRequestException('手机号已被使用');
    }

    // 加密密码
    const hashedPassword = await bcrypt.hash(createDoctorDto.password, 10);

    // 创建医生
    const doctor = this.doctorRepository.create({
      ...createDoctorDto,
      password: hashedPassword,
      consultationCount: 0,
      rating: 0,
      isActive: createDoctorDto.isActive ?? true,
      isGoldDoctor: createDoctorDto.isGoldDoctor ?? false,
    });

    const saved = await this.doctorRepository.save(doctor);

    // 返回时移除密码字段
    delete saved.password;
    return saved;
  }

  /**
   * 查询医生列表（支持分页和筛选）
   */
  async findAll(
    query: QueryDoctorDto,
    userRole?: string,
    userHospitalId?: number,
  ): Promise<PaginatedResult<Doctor>> {
    const {
      page = 1,
      pageSize = 10,
      sortOrder = 'DESC',
      sortBy = 'createdAt',
      name,
      phone,
      specialty,
      hospitalId,
      departmentId,
      isActive,
      isGoldDoctor,
      minRating,
      minExperience,
    } = query;

    const queryBuilder = this.doctorRepository
      .createQueryBuilder('doctor')
      .leftJoinAndSelect('doctor.hospital', 'hospital')
      .leftJoinAndSelect('doctor.department', 'department')
      .leftJoinAndSelect('doctor.serviceItems', 'serviceItems', 'serviceItems.isActive = :isActive', { isActive: true })
      .addOrderBy('serviceItems.sortOrder', 'ASC')
      .where('doctor.deletedAt IS NULL');

    // 权限过滤：医院管理员和员工只能看到自己医院的医生
    if (userRole === 'HOSPITAL_ADMIN' || userRole === 'STAFF') {
      if (userHospitalId) {
        queryBuilder.andWhere('doctor.hospitalId = :userHospitalId', {
          userHospitalId,
        });
      }
    }

    // 姓名模糊搜索
    if (name) {
      queryBuilder.andWhere('doctor.name LIKE :name', { name: `%${name}%` });
    }

    // 手机号精确搜索
    if (phone) {
      queryBuilder.andWhere('doctor.phone = :phone', { phone });
    }

    // 专业筛选
    if (specialty) {
      queryBuilder.andWhere('doctor.specialty LIKE :specialty', {
        specialty: `%${specialty}%`,
      });
    }

    // 医院筛选
    if (hospitalId) {
      queryBuilder.andWhere('doctor.hospitalId = :hospitalId', { hospitalId });
    }

    // 科室筛选
    if (departmentId) {
      queryBuilder.andWhere('doctor.departmentId = :departmentId', {
        departmentId,
      });
    }

    // 在职状态筛选
    if (isActive !== undefined) {
      queryBuilder.andWhere('doctor.isActive = :isActive', { isActive });
    }

    // 金牌医师筛选
    if (isGoldDoctor !== undefined) {
      queryBuilder.andWhere('doctor.isGoldDoctor = :isGoldDoctor', {
        isGoldDoctor,
      });
    }

    // 最低评分筛选
    if (minRating !== undefined) {
      queryBuilder.andWhere('doctor.rating >= :minRating', { minRating });
    }

    // 最低经验筛选
    if (minExperience !== undefined) {
      queryBuilder.andWhere('doctor.experience >= :minExperience', {
        minExperience,
      });
    }

    // 排序；咨询次数按已支付订单实时计算，避免依赖历史累计字段。
    const order = sortOrder === 'ASC' ? 'ASC' : 'DESC';
    if (sortBy === 'consultationCount') {
      queryBuilder
        .addSelect(
          (subQuery) =>
            subQuery
              .select('COUNT(consultationOrder.id)')
              .from('chat_orders', 'consultationOrder')
              .where('consultationOrder.doctorId = doctor.id')
              .andWhere('consultationOrder.status = :paidStatus'),
          'paidConsultationCount',
        )
        .setParameter('paidStatus', 'PAID')
        .orderBy('paidConsultationCount', order);
    } else {
      queryBuilder.orderBy(`doctor.${sortBy}`, order);
    }

    // 分页
    const skip = (page - 1) * pageSize;
    queryBuilder.skip(skip).take(pageSize);

    const [data, total] = await queryBuilder.getManyAndCount();
    await this.populateConsultationCounts(data);

    // 移除密码字段
    data.forEach((doctor) => delete doctor.password);

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 查询单个医生详情
   */
  async findOne(
    id: number,
    userRole?: string,
    userHospitalId?: number,
  ): Promise<Doctor> {
    const doctor = await this.doctorRepository.findOne({
      where: { id, deletedAt: null },
      relations: ['hospital', 'department'],
    });

    if (!doctor) {
      throw new NotFoundException('医生不存在');
    }

    // 权限检查
    if (userRole === 'HOSPITAL_ADMIN' || userRole === 'STAFF') {
      if (userHospitalId && doctor.hospitalId !== userHospitalId) {
        throw new ForbiddenException('无权查看其他医院的医生信息');
      }
    }

    await this.populateConsultationCounts([doctor]);

    // 移除密码字段
    delete doctor.password;
    return doctor;
  }

  /**
   * 查询单个医生详情（包含动态计算的统计数据）
   * 用于医生个人中心，咨询次数与公开详情统一按已支付订单统计
   */
  async findOneWithStats(id: number): Promise<Doctor> {
    return this.findOne(id);
  }

  /**
   * 按医院查询医生列表
   */
  async findByHospital(hospitalId: number): Promise<Doctor[]> {
    const doctors = await this.doctorRepository.find({
      where: { hospitalId, isActive: true, deletedAt: null },
      relations: ['department'],
      order: { rating: 'DESC' },
    });
    await this.populateConsultationCounts(doctors);

    // 移除密码字段
    doctors.forEach((doctor) => delete doctor.password);
    return doctors;
  }

  /**
   * 按科室查询医生列表
   */
  async findByDepartment(departmentId: number): Promise<Doctor[]> {
    const doctors = await this.doctorRepository.find({
      where: { departmentId, isActive: true, deletedAt: null },
      relations: ['hospital', 'department'],
      order: { rating: 'DESC' },
    });
    await this.populateConsultationCounts(doctors);

    // 移除密码字段
    doctors.forEach((doctor) => delete doctor.password);
    return doctors;
  }

  /**
   * 通过手机号查找医生账号。
   * 业务规则：密码找回允许禁用医生重置密码，真正登录仍由登录校验拦截 isActive。
   */
  async findByPhone(phone: string): Promise<Doctor | null> {
    return this.doctorRepository.findOne({
      where: { phone, deletedAt: null },
    });
  }

  /**
   * 更新医生信息
   */
  async update(
    id: number,
    updateDoctorDto: UpdateDoctorDto,
    userRole?: string,
    userHospitalId?: number,
  ): Promise<Doctor> {
    const doctor = await this.doctorRepository.findOne({
      where: { id, deletedAt: null },
    });

    if (!doctor) {
      throw new NotFoundException('医生不存在');
    }

    // 权限检查
    if (userRole === 'HOSPITAL_ADMIN' || userRole === 'STAFF') {
      if (userHospitalId && doctor.hospitalId !== userHospitalId) {
        throw new ForbiddenException('无权修改其他医院的医生信息');
      }
    }

    // 如果更新密码，需要加密
    if (updateDoctorDto.password) {
      updateDoctorDto.password = await bcrypt.hash(
        updateDoctorDto.password,
        10,
      );
    }

    // 验证用户名唯一性
    if (
      updateDoctorDto.username &&
      updateDoctorDto.username !== doctor.username
    ) {
      const existing = await this.doctorRepository.findOne({
        where: { username: updateDoctorDto.username },
      });
      if (existing) {
        throw new BadRequestException('用户名已存在');
      }
    }

    // 验证手机号唯一性
    if (updateDoctorDto.phone && updateDoctorDto.phone !== doctor.phone) {
      const existing = await this.doctorRepository.findOne({
        where: { phone: updateDoctorDto.phone },
      });
      if (existing) {
        throw new BadRequestException('手机号已被使用');
      }
    }

    await this.doctorRepository.update(id, updateDoctorDto);
    return this.findOne(id, userRole, userHospitalId);
  }

  /**
   * 删除医生（软删除）
   */
  async remove(
    id: number,
    userRole?: string,
    userHospitalId?: number,
  ): Promise<void> {
    const doctor = await this.doctorRepository.findOne({
      where: { id, deletedAt: null },
    });

    if (!doctor) {
      throw new NotFoundException('医生不存在');
    }

    // 权限检查
    if (userRole === 'HOSPITAL_ADMIN' || userRole === 'STAFF') {
      if (userHospitalId && doctor.hospitalId !== userHospitalId) {
        throw new ForbiddenException('无权删除其他医院的医生');
      }
    }

    const deletedDoctorInfo = {
      username: `del_${doctor.username}`,
      phone: `00${doctor.phone}`,
    };

    try {
      await this.doctorRepository.update(id, deletedDoctorInfo);
    } catch {
      await this.doctorRepository.update(id, {
        ...deletedDoctorInfo,
        phone: `${doctor.phone}00`,
      });
    }

    await this.doctorRepository.softDelete(id);
  }

  /**
   * 支付成功后同步咨询次数。
   * 保留历史方法名以兼容调用方，实际采用回算，确保重复支付通知不会重复累计。
   */
  async incrementConsultation(
    id: number,
    manager: EntityManager = this.doctorRepository.manager,
  ): Promise<void> {
    const counts = await this.getPaidConsultationCounts([id], manager);
    await manager.update(Doctor, id, {
      consultationCount: counts.get(id) ?? 0,
    });
  }

  /**
   * 验证医生登录（用于认证）
   */
  async validateDoctor(username: string, password: string): Promise<Doctor> {
    const doctor = await this.doctorRepository.findOne({
      where: { username, deletedAt: null },
      relations: ['hospital', 'department'],
    });

    if (!doctor) {
      throw new NotFoundException('用户名或密码错误');
    }

    // 验证密码
    const isPasswordValid = await bcrypt.compare(password, doctor.password);
    if (!isPasswordValid) {
      throw new NotFoundException('用户名或密码错误');
    }

    // 检查是否在职
    if (!doctor.isActive) {
      throw new ForbiddenException('该医生账号已被禁用');
    }

    // 更新最后登录时间
    await this.doctorRepository.update(doctor.id, { lastLoginAt: new Date() });

    // 移除密码字段
    delete doctor.password;
    return doctor;
  }

  /**
   * 通过手机号验证医生登录（用于手机号认证）
   */
  async validateDoctorByPhone(
    phone: string,
    password: string,
  ): Promise<Doctor> {
    const doctor = await this.doctorRepository.findOne({
      where: { phone, deletedAt: null },
      relations: ['hospital', 'department'],
    });

    if (!doctor) {
      throw new NotFoundException('手机号或密码错误');
    }

    // 验证密码
    const isPasswordValid = await bcrypt.compare(password, doctor.password);
    if (!isPasswordValid) {
      throw new NotFoundException('手机号或密码错误');
    }

    // 检查是否在职
    if (!doctor.isActive) {
      throw new ForbiddenException('该医生账号已被禁用');
    }

    // 更新最后登录时间
    await this.doctorRepository.update(doctor.id, { lastLoginAt: new Date() });

    // 移除密码字段
    delete doctor.password;
    return doctor;
  }

  /**
   * 获取医生统计信息
   */
  async getStatistics(hospitalId?: number): Promise<any> {
    const whereClause = hospitalId ? 'doctor.hospitalId = :hospitalId' : '1=1';
    const params = hospitalId ? { hospitalId } : {};

    const stats = await this.doctorRepository
      .createQueryBuilder('doctor')
      .select('COUNT(*)', 'totalDoctors')
      .addSelect('AVG(doctor.rating)', 'avgRating')
      .addSelect(
        'COUNT(CASE WHEN doctor.isActive = true THEN 1 END)',
        'activeDoctors',
      )
      .addSelect(
        'COUNT(CASE WHEN doctor.isGoldDoctor = true THEN 1 END)',
        'goldDoctors',
      )
      .where(whereClause, params)
      .andWhere('doctor.deletedAt IS NULL')
      .getRawOne();

    const consultationQuery = this.doctorRepository.manager
      .createQueryBuilder()
      .select('COUNT(consultationOrder.id)', 'count')
      .from('chat_orders', 'consultationOrder')
      .innerJoin(
        Doctor,
        'consultationDoctor',
        'consultationDoctor.id = consultationOrder.doctorId',
      )
      .where('consultationOrder.status = :paidStatus', {
        paidStatus: 'PAID',
      })
      .andWhere('consultationDoctor.deletedAt IS NULL');
    if (hospitalId) {
      consultationQuery.andWhere(
        'consultationDoctor.hospitalId = :hospitalId',
        { hospitalId },
      );
    }
    const consultationStats = await consultationQuery.getRawOne<{
      count: string;
    }>();

    const byDepartment = await this.doctorRepository
      .createQueryBuilder('doctor')
      .leftJoin('doctor.department', 'department')
      .select('department.name', 'departmentName')
      .addSelect('COUNT(*)', 'count')
      .where(whereClause, params)
      .andWhere('doctor.deletedAt IS NULL')
      .groupBy('department.id')
      .getRawMany();

    return {
      totalDoctors: parseInt(stats.totalDoctors || '0'),
      avgRating: parseFloat(stats.avgRating || '0').toFixed(2),
      totalConsultations: parseInt(consultationStats?.count || '0'),
      activeDoctors: parseInt(stats.activeDoctors || '0'),
      goldDoctors: parseInt(stats.goldDoctors || '0'),
      byDepartment: byDepartment.map((item) => ({
        departmentName: item.departmentName,
        count: parseInt(item.count),
      })),
    };
  }

  // ========== 收费项管理方法 ==========

  /**
   * 获取医生的收费项列表
   */
  async getServiceItems(doctorId: number): Promise<DoctorServiceItem[]> {
    return await this.serviceItemRepository.find({
      where: { doctorId, deletedAt: null },
      order: { sortOrder: 'ASC', createdAt: 'DESC' },
    });
  }

  /**
   * 通过 ID 查询收费项
   * 用于订单创建时获取收费项详情
   */
  async findServiceItemById(id: number): Promise<DoctorServiceItem | null> {
    return await this.serviceItemRepository.findOne({
      where: { id, deletedAt: null },
    });
  }

  /**
   * 添加收费项
   */
  async addServiceItem(
    doctorId: number,
    createDto: CreateServiceItemDto,
    userRole?: string,
    userHospitalId?: number,
  ): Promise<DoctorServiceItem> {
    const doctor = await this.doctorRepository.findOne({
      where: { id: doctorId, deletedAt: null },
    });

    if (!doctor) {
      throw new NotFoundException('医生不存在');
    }

    // 权限检查
    if (userRole === 'HOSPITAL_ADMIN' || userRole === 'STAFF') {
      if (userHospitalId && doctor.hospitalId !== userHospitalId) {
        throw new ForbiddenException('无权为其他医院的医生添加收费项');
      }
    }

    // 自动设置排序序号
    if (!createDto.sortOrder) {
      const maxSort = await this.serviceItemRepository
        .createQueryBuilder('item')
        .select('MAX(item.sortOrder)', 'max')
        .where('item.doctorId = :doctorId', { doctorId })
        .andWhere('item.deletedAt IS NULL')
        .getRawOne();
      createDto.sortOrder = (maxSort.max || 0) + 1;
    }

    const item = this.serviceItemRepository.create({
      ...createDto,
      doctorId,
      isActive: createDto.isActive ?? true,
    });

    return await this.serviceItemRepository.save(item);
  }

  /**
   * 批量添加收费项
   */
  async batchAddServiceItems(
    doctorId: number,
    batchDto: BatchCreateServiceItemsDto,
    userRole?: string,
    userHospitalId?: number,
  ): Promise<DoctorServiceItem[]> {
    const doctor = await this.doctorRepository.findOne({
      where: { id: doctorId, deletedAt: null },
    });

    if (!doctor) {
      throw new NotFoundException('医生不存在');
    }

    // 权限检查
    if (userRole === 'HOSPITAL_ADMIN' || userRole === 'STAFF') {
      if (userHospitalId && doctor.hospitalId !== userHospitalId) {
        throw new ForbiddenException('无权为其他医院的医生添加收费项');
      }
    }

    const items = batchDto.serviceItems.map((dto, index) => ({
      ...dto,
      doctorId,
      sortOrder: dto.sortOrder ?? index,
      isActive: dto.isActive ?? true,
    }));

    return await this.serviceItemRepository.save(items);
  }

  /**
   * 更新收费项
   */
  async updateServiceItem(
    doctorId: number,
    itemId: number,
    updateDto: UpdateServiceItemDto,
    userRole?: string,
    userHospitalId?: number,
  ): Promise<DoctorServiceItem> {
    const item = await this.serviceItemRepository.findOne({
      where: { id: itemId, doctorId, deletedAt: null },
    });

    if (!item) {
      throw new NotFoundException('收费项不存在');
    }

    // 权限检查
    if (userRole === 'HOSPITAL_ADMIN' || userRole === 'STAFF') {
      const doctor = await this.doctorRepository.findOne({
        where: { id: doctorId, deletedAt: null },
      });
      if (userHospitalId && doctor.hospitalId !== userHospitalId) {
        throw new ForbiddenException('无权修改其他医院的收费项');
      }
    }

    await this.serviceItemRepository.update(itemId, updateDto);

    return await this.serviceItemRepository.findOne({
      where: { id: itemId, deletedAt: null },
    });
  }

  /**
   * 删除收费项（软删除）
   */
  async removeServiceItem(
    doctorId: number,
    itemId: number,
    userRole?: string,
    userHospitalId?: number,
  ): Promise<void> {
    const item = await this.serviceItemRepository.findOne({
      where: { id: itemId, doctorId, deletedAt: null },
    });

    if (!item) {
      throw new NotFoundException('收费项不存在');
    }

    // 权限检查
    if (userRole === 'HOSPITAL_ADMIN' || userRole === 'STAFF') {
      const doctor = await this.doctorRepository.findOne({
        where: { id: doctorId, deletedAt: null },
      });
      if (userHospitalId && doctor.hospitalId !== userHospitalId) {
        throw new ForbiddenException('无权删除其他医院的收费项');
      }
    }

    await this.serviceItemRepository.softDelete(itemId);
  }

  /**
   * 更新医生在线状态
   * @param doctorId 医生 ID
   * @param onlineStatus 在线状态（ONLINE/OFFLINE）
   * @returns 更新后的医生信息
   */
  async updateOnlineStatus(
    doctorId: number,
    onlineStatus: 'ONLINE' | 'OFFLINE',
  ): Promise<Doctor> {
    const doctor = await this.doctorRepository.findOne({
      where: { id: doctorId, deletedAt: null },
    });

    if (!doctor) {
      throw new NotFoundException('医生不存在');
    }

    // 更新在线状态
    doctor.onlineStatus = onlineStatus;
    await this.doctorRepository.save(doctor);

    // 通过 WebSocket 广播医生在线状态变化
    try {
      const chatGateway = this.moduleRef.get('ChatGateway', { strict: false });
      if (chatGateway && typeof chatGateway.notifyDoctorOnlineStatus === 'function') {
        chatGateway.notifyDoctorOnlineStatus(doctorId, onlineStatus);
      }
    } catch (error) {
      // 如果 ChatGateway 不可用，仅记录日志，不影响主流程
      this.logger.warn('[DoctorsService] 无法广播医生在线状态变化:', error.message);
    }

    // 移除密码字段
    delete doctor.password;
    return doctor;
  }
}
