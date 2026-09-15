import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { InjectQueue } from '@nestjs/bull';
import { Queue } from 'bull';
import { AiDiagnosisReport } from './entities/ai-diagnosis-report.entity';
import { CreateReportDto, QueryReportsDto } from './dto';
import { WESTERN_DIAGNOSIS_QUEUE, TCM_DIAGNOSIS_QUEUE } from './queues';
import { User } from '../users/entities/user.entity';
import { Pet } from '../pets/entities/pet.entity';
import { PetSnapshot } from './interfaces/pet-snapshot.interface';
import {
  createBusinessException,
  ErrorCode,
} from '../common/constants/error-codes';

/**
 * AI 问诊报告服务
 */
@Injectable()
export class AiDiagnosisReportService {
  private readonly logger = new Logger(AiDiagnosisReportService.name);

  constructor(
    @InjectRepository(AiDiagnosisReport)
    private readonly reportRepository: Repository<AiDiagnosisReport>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Pet)
    private readonly petRepository: Repository<Pet>,
    @InjectQueue(WESTERN_DIAGNOSIS_QUEUE)
    private readonly westernQueue: Queue,
    @InjectQueue(TCM_DIAGNOSIS_QUEUE)
    private readonly tcmQueue: Queue,
  ) {}

  /**
   * 创建 AI 问诊报告
   * @param userId 当前用户 ID
   * @param createReportDto 创建报告 DTO
   * @returns 创建的报告
   */
  async create(userId: number, createReportDto: CreateReportDto) {
    const { petId, symptoms, selfCheckSnapshot, basicInfo, diagnosisImages } = createReportDto;

    // 调试日志：打印自查表快照
    this.logger.log('[创建AI诊断] 收到自查表快照', {
      length: selfCheckSnapshot?.length,
      isArray: Array.isArray(selfCheckSnapshot),
      data: JSON.stringify(selfCheckSnapshot, null, 2),
    });

    // 验证宠物是否属于当前用户，并加载关联的分类信息
    const pet = await this.petRepository.findOne({
      where: { id: petId, ownerId: userId },
      relations: ['category', 'subCategory'], // 加载分类关联
    });

    if (!pet) {
      throw createBusinessException(ErrorCode.PET_NOT_FOUND);
    }

    // ========== ✅ 新增：创建宠物快照 ==========
    const petSnapshot = this.createPetSnapshot(pet);

    // 组合完整的症状描述（入库到 symptoms 字段，并作为 AI 诊断上下文）
    const fullDescription = this.buildFullSymptomsDescription({
      pet,
      symptoms,
      selfCheckSnapshot,
      basicInfo,
    });

    // 创建报告记录（包含快照）
    const report = this.reportRepository.create({
      userId,
      petId,
      // 保存组合后的完整描述（宠物信息、疫苗/驱虫、生理指标、自查症状、用户主诉），
      // 与传给 AI 队列的诊断上下文保持一致，便于医生端/管理端回溯完整问诊信息。
      symptoms: fullDescription,
      selfCheckSnapshot,
      basicInfo, // 保存基础信息
      diagnosisImages, // 保存诊断图片
      petSnapshot, // ========== ✅ 新增：保存快照 ==========
      status: 'PENDING',
    });

    const savedReport = await this.reportRepository.save(report);

    // 添加到队列
    await this.addJobsToQueue(savedReport.id, fullDescription);

    // 更新状态为 PROCESSING
    await this.reportRepository.update(savedReport.id, {
      status: 'PROCESSING',
    });

    // 返回更新后的报告
    const updatedReport = await this.reportRepository.findOne({
      where: { id: savedReport.id },
    });

    return updatedReport;
  }

  /**
   * 组合完整的症状描述
   * 将宠物信息、自查表结果、症状描述、基础信息组合成一段完整的文字
   */
  private buildFullSymptomsDescription(params: {
    pet: Pet;
    symptoms: string;
    selfCheckSnapshot: any[];
    basicInfo?: {
      bodyTemperature?: string;
      heartRate?: string;
      breathe?: string;
    };
  }): string {
    const { pet, symptoms, selfCheckSnapshot, basicInfo } = params;

    const parts: string[] = [];

    // 1. 宠物基本信息
    // 使用 category（类型）和 subCategory（品种）
    const categoryName = pet.category?.name || '';
    const breedName = pet.subCategory?.name || '';
    parts.push(
      `宠物信息：${pet.name}，${categoryName}，${breedName}，${this.calculateAge(pet.birthDate)}`,
    );

    // ========== ✅ 新增：疫苗信息 ==========
    const vaccineInfo = this.buildVaccineDescription(pet);
    if (vaccineInfo) {
      parts.push(vaccineInfo);
    }

    // ========== ✅ 新增：驱虫信息 ==========
    const dewormingInfo = this.buildDewormingDescription(pet);
    if (dewormingInfo) {
      parts.push(dewormingInfo);
    }

    // 2. 基础生理指标（如果有）
    if (basicInfo) {
      const vitalSigns: string[] = [];
      if (basicInfo.bodyTemperature)
        vitalSigns.push(`体温${basicInfo.bodyTemperature}°C`);
      if (basicInfo.heartRate)
        vitalSigns.push(`心率${basicInfo.heartRate}次/分钟`);
      if (basicInfo.breathe)
        vitalSigns.push(`呼吸频率${basicInfo.breathe}次/分钟`);

      if (vitalSigns.length > 0) {
        parts.push(`生理指标：${vitalSigns.join('，')}`);
      }
    }

    // 3. 自查表症状（如果有）
    if (selfCheckSnapshot && selfCheckSnapshot.length > 0) {
      const selectedSymptoms: string[] = [];

      selfCheckSnapshot.forEach((list: any) => {
        list.questions.forEach((question: any) => {
          // 提取已选择的选项
          const selectedOptions = question.options
            ?.filter((opt: any) => opt.selected)
            .map((opt: any) => opt.optionText);

          if (selectedOptions && selectedOptions.length > 0) {
            const questionText = question.questionText?.trim();
            const answerText = selectedOptions.join('、');
            selectedSymptoms.push(questionText ? `${questionText}：${answerText}` : answerText);
          }
        });
      });

      if (selectedSymptoms.length > 0) {
        parts.push(`自查症状：${selectedSymptoms.join('、')}`);
      }
    }

    // 4. 用户输入的症状描述
    if (symptoms) {
      parts.push(`症状描述：${symptoms}`);
    }

    return parts.join('；');
  }

  /**
   * 格式化日期时间
   * @param date 日期对象
   * @returns 格式化后的日期时间字符串（YYYY-MM-DD HH:mm:ss）
   */
  private formatDateTime(date: Date): string {
    if (!date) return null;
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    const seconds = String(date.getSeconds()).padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
  }

  /**
   * 格式化日期为 YYYY-MM-DD
   * @param date 日期对象
   * @returns 格式化后的日期字符串
   */
  private formatDate(date: Date): string {
    if (!date) return null;
    const d = new Date(date);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  /**
   * 计算两个日期之间的天数差
   * @param date1 日期1
   * @param date2 日期2（可选，默认为当前日期）
   * @returns 天数差（date2 - date1）
   */
  private calculateDaysDiff(date1: Date, date2?: Date): number {
    const d1 = new Date(date1).setHours(0, 0, 0, 0);
    const d2 = date2
      ? new Date(date2).setHours(0, 0, 0, 0)
      : new Date().setHours(0, 0, 0, 0);

    return Math.floor((d2 - d1) / (1000 * 60 * 60 * 24));
  }

  /**
   * 构建疫苗接种情况的语义化描述
   * @param pet 宠物实体
   * @returns 疫苗接种描述（如果没有接种记录则返回 null）
   */
  private buildVaccineDescription(pet: Pet): string | null {
    // 如果没有任何疫苗记录，不返回描述
    if (!pet.lastVaccineAt && !pet.nextVaccineAt && pet.vaccineCount === 0) {
      return null;
    }

    const parts: string[] = [];

    // 已接种针数
    if (pet.vaccineCount > 0) {
      parts.push(`已接种${pet.vaccineCount}针疫苗`);
    }

    // 上次接种时间
    if (pet.lastVaccineAt) {
      const daysSinceLast = this.calculateDaysDiff(pet.lastVaccineAt);
      parts.push(`上次接种时间${this.formatDate(pet.lastVaccineAt)}（${daysSinceLast}天前）`);
    }

    // 下次接种时间
    if (pet.nextVaccineAt) {
      const daysUntilNext = this.calculateDaysDiff(new Date(), pet.nextVaccineAt);

      if (daysUntilNext < 0) {
        // 已经过期
        parts.push(
          `下次应于${this.formatDate(pet.nextVaccineAt)}接种（已逾期${Math.abs(daysUntilNext)}天）`,
        );
      } else if (daysUntilNext === 0) {
        // 今天到期
        parts.push(`下次应于${this.formatDate(pet.nextVaccineAt)}接种（今天）`);
      } else {
        // 未到期
        parts.push(`下次应于${this.formatDate(pet.nextVaccineAt)}接种（还有${daysUntilNext}天）`);
      }
    }

    return parts.length > 0 ? `疫苗接种情况：${parts.join('，')}` : null;
  }

  /**
   * 构建驱虫情况的语义化描述
   * @param pet 宠物实体
   * @returns 驱虫情况描述（如果没有驱虫记录则返回 null）
   */
  private buildDewormingDescription(pet: Pet): string | null {
    // 如果没有任何驱虫记录，不返回描述
    if (!pet.lastDewormingAt && !pet.nextDewormingAt && pet.dewormingCount === 0) {
      return null;
    }

    const parts: string[] = [];

    // 驱虫次数
    if (pet.dewormingCount > 0) {
      parts.push(`已驱虫${pet.dewormingCount}次`);
    }

    // 上次驱虫时间
    if (pet.lastDewormingAt) {
      const daysSinceLast = this.calculateDaysDiff(pet.lastDewormingAt);
      parts.push(`上次驱虫时间${this.formatDate(pet.lastDewormingAt)}（${daysSinceLast}天前）`);
    }

    // 下次驱虫时间
    if (pet.nextDewormingAt) {
      const daysUntilNext = this.calculateDaysDiff(new Date(), pet.nextDewormingAt);

      if (daysUntilNext < 0) {
        // 已经过期
        parts.push(
          `下次应于${this.formatDate(pet.nextDewormingAt)}驱虫（已逾期${Math.abs(daysUntilNext)}天）`,
        );
      } else if (daysUntilNext === 0) {
        // 今天到期
        parts.push(`下次应于${this.formatDate(pet.nextDewormingAt)}驱虫（今天）`);
      } else {
        // 未到期
        parts.push(`下次应于${this.formatDate(pet.nextDewormingAt)}驱虫（还有${daysUntilNext}天）`);
      }
    }

    return parts.length > 0 ? `驱虫情况：${parts.join('，')}` : null;
  }

  /**
   * 创建宠物信息快照
   * 将宠物及其关联数据扁平化保存
   * @param pet 宠物实体（需包含 category 和 subCategory 关联）
   * @returns 扁平化的宠物快照
   */
  private createPetSnapshot(pet: Pet): PetSnapshot {
    /**
     * 安全地将日期转换为 ISO 字符串
     * 处理 Date 对象、字符串、null 等各种情况
     */
    const toISODateString = (date: Date | string | null | undefined): string | null => {
      if (!date) return null;
      try {
        const d = date instanceof Date ? date : new Date(date as string);
        // 检查日期是否有效
        if (isNaN(d.getTime())) return null;
        return d.toISOString();
      } catch (e) {
        this.logger.error('[日期转换失败]', date, e);
        return null;
      }
    };

    return {
      // ========== 基础信息 ==========
      id: pet.id,
      name: pet.name,
      avatar: pet.avatar,
      gender: pet.gender,
      birthDate: toISODateString(pet.birthDate as any),
      weight: pet.weight,

      // ========== 分类信息（扁平化） ==========
      categoryId: pet.categoryId,
      categoryName: pet.category?.name || null,
      subCategoryId: pet.subCategoryId,
      subCategoryName: pet.subCategory?.name || null,

      // ========== 标签和绝育 ==========
      tags: pet.tags || [],
      isNeutered: pet.isNeutered,

      // ========== 统计信息 ==========
      appointmentCount: pet.appointmentCount,
      lastAppointmentAt: toISODateString(pet.lastAppointmentAt as any),
      consultationCount: pet.consultationCount,

      // ========== 健康管理 ==========
      lastDewormingAt: toISODateString(pet.lastDewormingAt as any),
      nextDewormingAt: toISODateString(pet.nextDewormingAt as any),
      lastVaccineAt: toISODateString(pet.lastVaccineAt as any),
      nextVaccineAt: toISODateString(pet.nextVaccineAt as any),
      lastCheckupAt: toISODateString(pet.lastCheckupAt as any),
      nextCheckupAt: toISODateString(pet.nextCheckupAt as any),
      vaccineCount: pet.vaccineCount,
      dewormingCount: pet.dewormingCount,
      checkupCount: pet.checkupCount,

      // ========== 护理计划 ==========
      carePlan: pet.carePlan,
      carePlanStatus: pet.carePlanStatus,
      carePlanJobId: pet.carePlanJobId,
      carePlanGeneratedAt: toISODateString(pet.carePlanGeneratedAt as any),
      carePlanError: pet.carePlanError,
    };
  }

  /**
   * 计算宠物年龄
   * @param birthDate 出生日期
   * @returns 年龄描述字符串
   */
  private calculateAge(birthDate: Date): string {
    if (!birthDate) return '年龄未知';

    const now = new Date();
    const diff = now.getTime() - new Date(birthDate).getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));

    // 如果出生日期是未来日期，返回提示信息
    if (days < 0) {
      return '出生日期异常（未来日期）';
    }

    if (days < 30) {
      return `${days}日龄`;
    } else if (days < 365) {
      const months = Math.floor(days / 30);
      return `${months}个月大`;
    } else {
      const years = Math.floor(days / 365);
      const months = Math.floor((days % 365) / 30);
      return months > 0 ? `${years}岁${months}个月` : `${years}岁`;
    }
  }

  /**
   * 添加诊断任务到队列
   */
  private async addJobsToQueue(reportId: number, symptoms: string) {
    // 西医诊断任务配置
    const westernJob = await this.westernQueue.add(
      'diagnose',
      { reportId, symptoms },
      {
        attempts: 3, // 最多重试 3 次
        backoff: {
          type: 'fixed',
          delay: 5 * 60 * 1000, // 失败后 5 分钟重试
        },
        timeout: 8 * 60 * 60 * 1000, // 8 小时超时
        removeOnComplete: false,
        removeOnFail: false,
      },
    );

    // 中医诊断任务配置
    const tcmJob = await this.tcmQueue.add(
      'diagnose',
      { reportId, symptoms },
      {
        attempts: 3,
        backoff: {
          type: 'fixed',
          delay: 5 * 60 * 1000,
        },
        timeout: 8 * 60 * 60 * 1000,
        removeOnComplete: false,
        removeOnFail: false,
      },
    );

    // 保存 Job ID
    await this.reportRepository.update(reportId, {
      westernJobId: westernJob.id.toString(),
      tcmJobId: tcmJob.id.toString(),
    });
  }

  /**
   * 查询报告列表
   * @param queryDto 查询参数
   * @param userId 当前用户 ID
   * @param userRole 当前用户角色
   * @returns 分页的报告列表
   */
  async findAll(queryDto: QueryReportsDto, userId: number, userRole: string) {
    const {
      page = 1,
      pageSize = 10,
      id,
      userId: queryUserId,
      userPhone,
      petId,
      status,
      keyword,
      startDate,
      endDate,
    } = queryDto;
    const trimmedUserPhone = userPhone?.trim();
    const trimmedKeyword = keyword?.trim();

    // 构建查询条件
    const where: any = {
      isDeleted: false,
    };

    // 权限控制：普通用户只能查看自己的报告
    if (userRole === 'USER') {
      where.userId = userId;
    } else if (queryUserId) {
      // 管理员和医生可以按用户筛选
      where.userId = queryUserId;
    }

    // 宠物筛选
    if (petId) {
      where.petId = petId;
    }

    // 状态筛选
    if (status) {
      where.status = status;
    }

    // 关键词搜索 - 需要使用 queryBuilder
    // ========== ✅ 修改：只关联 User 表 ==========
    let queryBuilder = this.reportRepository
      .createQueryBuilder('report')
      .leftJoinAndSelect('report.user', 'user') // 只关联用户
      // .leftJoinAndSelect('report.pet', 'pet') // ✅ 移除：不再关联 Pet 表
      .where('report.isDeleted = :isDeleted', { isDeleted: false });

    // 权限控制
    if (userRole === 'USER') {
      queryBuilder = queryBuilder.andWhere('report.userId = :userId', {
        userId,
      });
    } else if (queryUserId) {
      queryBuilder = queryBuilder.andWhere('report.userId = :queryUserId', {
        queryUserId,
      });
    }

    // 宠物筛选
    if (petId) {
      queryBuilder = queryBuilder.andWhere('report.petId = :petId', { petId });
    }

    // 报告 ID 筛选
    if (id) {
      queryBuilder = queryBuilder.andWhere('report.id = :id', { id });
    }

    // 状态筛选
    if (status) {
      queryBuilder = queryBuilder.andWhere('report.status = :status', {
        status,
      });
    }

    // 用户手机号搜索
    if (trimmedUserPhone) {
      queryBuilder = queryBuilder.andWhere('user.phone LIKE :userPhone', {
        userPhone: `%${trimmedUserPhone}%`,
      });
    }

    // 关键词搜索
    if (trimmedKeyword) {
      queryBuilder = queryBuilder.andWhere('report.symptoms LIKE :keyword', {
        keyword: `%${trimmedKeyword}%`,
      });
    }

    // 日期范围筛选
    if (startDate) {
      queryBuilder = queryBuilder.andWhere('report.createdAt >= :startDate', {
        startDate: new Date(startDate),
      });
    }
    if (endDate) {
      const endDateTime = new Date(endDate);
      endDateTime.setHours(23, 59, 59, 999);
      queryBuilder = queryBuilder.andWhere('report.createdAt <= :endDate', {
        endDate: endDateTime,
      });
    }

    // 排序：按创建时间倒序
    queryBuilder = queryBuilder.orderBy('report.createdAt', 'DESC');

    // 分页并获取结果
    const result = await queryBuilder
      .skip((page - 1) * pageSize)
      .take(pageSize)
      .getRawAndEntities();

    const entities = result.entities;

    // 获取总数（需要在排序和分页之前获取）
    const totalQuery = this.reportRepository
      .createQueryBuilder('report')
      .leftJoin('report.user', 'user')
      .where('report.isDeleted = :isDeleted', { isDeleted: false });

    if (userRole === 'USER') {
      totalQuery.andWhere('report.userId = :userId', { userId });
    } else if (queryUserId) {
      totalQuery.andWhere('report.userId = :queryUserId', { queryUserId });
    }
    if (petId) {
      totalQuery.andWhere('report.petId = :petId', { petId });
    }
    if (id) {
      totalQuery.andWhere('report.id = :id', { id });
    }
    if (status) {
      totalQuery.andWhere('report.status = :status', { status });
    }
    if (trimmedUserPhone) {
      totalQuery.andWhere('user.phone LIKE :userPhone', {
        userPhone: `%${trimmedUserPhone}%`,
      });
    }
    if (trimmedKeyword) {
      totalQuery.andWhere('report.symptoms LIKE :keyword', {
        keyword: `%${trimmedKeyword}%`,
      });
    }
    if (startDate) {
      totalQuery.andWhere('report.createdAt >= :startDate', {
        startDate: new Date(startDate),
      });
    }
    if (endDate) {
      const endDateTime = new Date(endDate);
      endDateTime.setHours(23, 59, 59, 999);
      totalQuery.andWhere('report.createdAt <= :endDate', {
        endDate: endDateTime,
      });
    }

    const total = await totalQuery.getCount();

    // 调试日志：打印查询结果
    this.logger.log('[AI诊断报告查询] 查询到记录数:', entities.length);
    if (entities.length > 0) {
      this.logger.log('[AI诊断报告查询] 第一条记录示例:', {
        id: entities[0].id,
        hasUser: !!entities[0].user,
        user: entities[0].user,
      });
      if (result.raw && result.raw.length > 0) {
        this.logger.log('[AI诊断报告查询] 原始数据示例:', result.raw[0]);
      }
    }

    // 修改：从快照获取宠物名称
    // 转换为响应格式
    const data = entities.map((report) => ({
      id: report.id,
      userId: report.userId,
      petId: report.petId,
      petName: report.petSnapshot?.name || '未知', // ✅ 从快照获取
      userPhone: report.user?.phone,
      symptoms: report.symptoms,
      status: report.status,
      createdAt: this.formatDateTime(report.createdAt),
      completedAt: report.completedAt
        ? this.formatDateTime(report.completedAt)
        : null,
      updatedAt: this.formatDateTime(report.updatedAt),
    }));

    return {
      data,
      total,
      page,
      pageSize,
    };
  }

  /**
   * 获取报告详情
   * @param id 报告 ID
   * @param userId 当前用户 ID
   * @param userRole 当前用户角色
   * @returns 报告详情
   */
  async findOne(id: number, userId: number, userRole: string) {
    // ========== ✅ 修改：只关联 User 表，不再关联 Pet 表 ==========
    const report = await this.reportRepository.findOne({
      where: { id, isDeleted: false },
      relations: ['user'], // 只关联用户
    });

    if (!report) {
      throw new NotFoundException('报告不存在');
    }

    // 权限控制：普通用户只能查看自己的报告
    if (userRole === 'USER' && report.userId !== userId) {
      throw new ForbiddenException('无权访问该报告');
    }

    // 从快照中提取宠物信息
    const petSnapshot = report.petSnapshot;

    // 调试日志：打印自查表快照（详情接口）
    this.logger.log('[查询AI诊断详情] 自查表快照数据:', {
      reportId: report.id,
      selfCheckSnapshot: report.selfCheckSnapshot,
      type: typeof report.selfCheckSnapshot,
      isArray: Array.isArray(report.selfCheckSnapshot),
      length: report.selfCheckSnapshot?.length,
      firstElement: report.selfCheckSnapshot?.[0],
      data: JSON.stringify(report.selfCheckSnapshot, null, 2),
    });

    return {
      id: report.id,
      userId: report.userId,
      userName: report.user?.username,
      userPhone: report.user?.phone,
      petId: report.petId,

      // ========== ✅ 宠物信息全部来自快照 ==========
      petInfo: petSnapshot
        ? {
            id: petSnapshot.id,
            name: petSnapshot.name,
            avatar: petSnapshot.avatar,
            gender: petSnapshot.gender,
            birthDate: petSnapshot.birthDate,
            weight: petSnapshot.weight,
            categoryId: petSnapshot.categoryId,
            categoryName: petSnapshot.categoryName,
            subCategoryId: petSnapshot.subCategoryId,
            subCategoryName: petSnapshot.subCategoryName,
            tags: petSnapshot.tags,
            isNeutered: petSnapshot.isNeutered,
            appointmentCount: petSnapshot.appointmentCount,
            lastAppointmentAt: petSnapshot.lastAppointmentAt,
            consultationCount: petSnapshot.consultationCount,
            lastDewormingAt: petSnapshot.lastDewormingAt,
            nextDewormingAt: petSnapshot.nextDewormingAt,
            lastVaccineAt: petSnapshot.lastVaccineAt,
            nextVaccineAt: petSnapshot.nextVaccineAt,
            lastCheckupAt: petSnapshot.lastCheckupAt,
            nextCheckupAt: petSnapshot.nextCheckupAt,
            vaccineCount: petSnapshot.vaccineCount,
            dewormingCount: petSnapshot.dewormingCount,
            checkupCount: petSnapshot.checkupCount,
            carePlan: petSnapshot.carePlan,
            carePlanStatus: petSnapshot.carePlanStatus,
            carePlanJobId: petSnapshot.carePlanJobId,
            carePlanGeneratedAt: petSnapshot.carePlanGeneratedAt,
            carePlanError: petSnapshot.carePlanError,
          }
        : null,

      status: report.status,
      symptoms: report.symptoms,
      selfCheckSnapshot: report.selfCheckSnapshot,
      diagnosisImages: report.diagnosisImages, // 诊断图片
      basicInfo: report.basicInfo, // 基础信息
      westernDiagnosis: report.westernDiagnosis,
      tcmDiagnosis: report.tcmDiagnosis,
      errorMessage: report.errorMessage,
      createdAt: this.formatDateTime(report.createdAt),
      updatedAt: this.formatDateTime(report.updatedAt),
      completedAt: report.completedAt
        ? this.formatDateTime(report.completedAt)
        : null,
      retryCount: report.retryCount,
    };
  }

  /**
   * 删除报告（软删除）
   * @param id 报告 ID
   * @param userRole 当前用户角色
   */
  async remove(id: number, userRole: string) {
    // 权限控制：只有超级管理员可以删除
    if (userRole !== 'SUPER_ADMIN') {
      throw new ForbiddenException('无权删除报告');
    }

    const report = await this.reportRepository.findOne({
      where: { id, isDeleted: false },
    });

    if (!report) {
      throw new NotFoundException('报告不存在');
    }

    // 软删除
    await this.reportRepository.update(id, { isDeleted: true });

    return { message: '报告删除成功' };
  }

  /**
   * 根据手机号查询用户的宠物列表
   * @param phone 用户手机号
   * @returns 宠物列表
   */
  async getPetsByUserPhone(phone: string) {
    const user = await this.userRepository.findOne({
      where: { phone },
    });

    if (!user) {
      throw createBusinessException(ErrorCode.USER_NOT_FOUND);
    }

    // 加载宠物及其关联的分类信息
    const pets = await this.petRepository.find({
      where: { ownerId: user.id },
      relations: ['category', 'subCategory'], // 加载分类关联
    });

    return pets.map((pet) => ({
      id: pet.id,
      name: pet.name,
      breed: pet.subCategory?.name || '未知', // 品种
      age: pet.birthDate ? this.calculateAge(pet.birthDate) : '未知',
      gender: pet.gender === 1 ? '弟弟' : pet.gender === 2 ? '妹妹' : '未知',
      avatar: pet.avatar || '', // 头像
      weight: pet.weight || 0, // ✅ 新增：体重
      userId: pet.ownerId,
      userName: user.username,
    }));
  }
}
