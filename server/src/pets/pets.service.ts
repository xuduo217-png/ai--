import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { InjectQueue } from "@nestjs/bull";
import { Repository, In } from "typeorm";
import { Queue } from "bull";
import { Pet } from "./entities/pet.entity";
import { PetGender } from "./entities/pet.entity";
import { CreatePetDto } from "./dto/create-pet.dto";
import { UpdatePetDto } from "./dto/update-pet.dto";
import { QueryPetDto } from "./dto/query-pet.dto";
import { PaginatedResult } from "../common/dto/pagination.dto";
import { PET_CARE_PLAN_QUEUE } from "./queues";

@Injectable()
export class PetsService {
  private readonly logger = new Logger(PetsService.name);

  constructor(
    @InjectRepository(Pet)
    private petRepository: Repository<Pet>,
    @InjectQueue(PET_CARE_PLAN_QUEUE)
    private carePlanQueue: Queue,
  ) {}

  async create(createPetDto: CreatePetDto, ownerId: number): Promise<Pet> {
    const pet = this.petRepository.create({
      ...createPetDto,
      ownerId,
      appointmentCount: 0,
      consultationCount: 0,
    });
    const savedPet = await this.petRepository.save(pet);

    // 自动触发护理计划生成
    await this.triggerCarePlanGeneration(savedPet.id);

    return savedPet;
  }

  async findAll(query: QueryPetDto): Promise<PaginatedResult<Pet>> {
    const {
      page = 1,
      pageSize = 10,
      sortOrder = "DESC",
      sortBy = "createdAt",
      ownerId,
      categoryId,
      subCategoryId,
      name,
      gender,
      minWeight,
      maxWeight,
      tags,
      isNeutered,
    } = query;

    const queryBuilder = this.petRepository
      .createQueryBuilder("pet")
      .leftJoinAndSelect("pet.owner", "owner")
      .leftJoinAndSelect("pet.category", "category")
      .leftJoinAndSelect("pet.subCategory", "subCategory")
      .where("pet.deletedAt IS NULL"); // 排除已软删除的记录

    // 用户过滤
    if (ownerId) {
      queryBuilder.andWhere("pet.ownerId = :ownerId", { ownerId });
    }

    // 一级分类过滤
    if (categoryId) {
      queryBuilder.andWhere("pet.categoryId = :categoryId", { categoryId });
    }

    // 二级分类过滤
    if (subCategoryId) {
      queryBuilder.andWhere("pet.subCategoryId = :subCategoryId", {
        subCategoryId,
      });
    }

    // 名字模糊搜索
    if (name) {
      queryBuilder.andWhere("pet.name LIKE :name", { name: `%${name}%` });
    }

    // 性别过滤
    if (gender) {
      queryBuilder.andWhere("pet.gender = :gender", { gender });
    }

    // 体重范围过滤
    if (minWeight !== undefined && maxWeight !== undefined) {
      queryBuilder.andWhere("pet.weight BETWEEN :minWeight AND :maxWeight", {
        minWeight,
        maxWeight,
      });
    } else if (minWeight !== undefined) {
      queryBuilder.andWhere("pet.weight >= :minWeight", { minWeight });
    } else if (maxWeight !== undefined) {
      queryBuilder.andWhere("pet.weight <= :maxWeight", { maxWeight });
    }

    // 绝育状态过滤
    if (isNeutered !== undefined) {
      queryBuilder.andWhere("pet.isNeutered = :isNeutered", { isNeutered });
    }

    // 标签过滤
    if (tags) {
      const tagArray = tags.split(",").map((tag) => tag.trim());
      queryBuilder.andWhere("pet.tags LIKE :tags", {
        tags: `%${tagArray[0]}%`,
      });
    }

    // 排序
    const order = sortOrder === "ASC" ? "ASC" : "DESC";
    queryBuilder.orderBy(`pet.${sortBy}`, order);

    // 分页
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

  async findOne(id: number, userId?: number, userRole?: string): Promise<Pet> {
    const pet = await this.petRepository.findOne({
      where: { id, deletedAt: null }, // 排除已软删除的记录
      relations: ["owner", "category", "subCategory"],
    });

    if (!pet) {
      throw new NotFoundException("宠物不存在");
    }

    // 权限检查
    if (userRole === "USER" && pet.ownerId !== userId) {
      throw new ForbiddenException("无权查看此宠物信息");
    }

    return pet;
  }

  /**
   * 更新宠物信息
   * 注意：普通用户（USER）不能修改 ownerId，只有管理员（SUPER_ADMIN、STAFF）可以修改
   */
  async update(
    id: number,
    updatePetDto: UpdatePetDto,
    userId?: number,
    userRole?: string,
  ): Promise<Pet> {
    const pet = await this.findOne(id, userId, userRole);

    // 权限检查
    if (userRole === "USER" && pet.ownerId !== userId) {
      throw new ForbiddenException("无权修改此宠物信息");
    }

    // 普通用户不能修改 ownerId（防止转移宠物所有权）
    const updateData = { ...updatePetDto };
    if (userRole === "USER" && updateData.ownerId !== undefined) {
      delete updateData.ownerId;
    }

    // 检测关键字段是否变化
    const keyFieldsChanged = this.checkKeyFieldsChanged(pet, updateData);

    await this.petRepository.update(id, updateData);

    // 如果关键字段发生变化，触发护理计划重新生成
    if (keyFieldsChanged) {
      await this.triggerCarePlanGeneration(id);
    }

    return this.findOne(id, userId, userRole);
  }

  async remove(id: number, userId?: number, userRole?: string): Promise<void> {
    const pet = await this.findOne(id, userId, userRole);

    // 权限检查
    if (userRole === "USER" && pet.ownerId !== userId) {
      throw new ForbiddenException("无权删除此宠物信息");
    }

    /**
     * 先清空分类引用再执行软删除
     * 业务原因：宠物删除后仍需保留历史档案，但分类删除不应再被软删除宠物卡住
     */
    await this.petRepository.manager.transaction(async (transactionManager) => {
      await transactionManager
        .createQueryBuilder()
        .update(Pet)
        .set({
          categoryId: () => "NULL",
          subCategoryId: () => "NULL",
        })
        .where("id = :id", { id })
        .execute();

      await transactionManager.softDelete(Pet, id);
    });
  }

  async findByOwner(ownerId: number, categoryId?: number): Promise<Pet[]> {
    const where: any = { ownerId, deletedAt: null };

    // 如果指定了一级分类，添加筛选条件
    if (categoryId) {
      where.categoryId = categoryId;
    }

    return this.petRepository.find({
      where,
      relations: ["category", "subCategory"],
      order: { createdAt: "DESC" },
    });
  }

  /**
   * 根据用户 ID 查找宠物列表
   * @param userId 用户 ID
   * @returns 宠物列表
   */
  async findByUserId(userId: number): Promise<Pet[]> {
    return this.petRepository.find({
      where: { ownerId: userId, deletedAt: null },
      order: { createdAt: "DESC" },
    });
  }

  // ========== 统计功能 ==========

  async getStatistics(userId?: number, userRole?: string): Promise<any> {
    const queryBuilder = this.petRepository
      .createQueryBuilder("pet")
      .where("pet.deletedAt IS NULL");

    if (userRole === "USER") {
      queryBuilder.andWhere("pet.ownerId = :userId", { userId });
    }

    const total = await queryBuilder.getCount();

    // 按一级分类统计
    const byCategory = await this.petRepository
      .createQueryBuilder("pet")
      .select("pet.categoryId", "categoryId")
      .addSelect("COUNT(*)", "count")
      .where(userRole === "USER" ? "pet.ownerId = :userId" : "1=1", { userId })
      .andWhere("pet.deletedAt IS NULL")
      .andWhere("pet.categoryId IS NOT NULL")
      .groupBy("pet.categoryId")
      .getRawMany();

    // 按性别统计
    const byGender = await this.petRepository
      .createQueryBuilder("pet")
      .select("pet.gender", "gender")
      .addSelect("COUNT(*)", "count")
      .where(userRole === "USER" ? "pet.ownerId = :userId" : "1=1", { userId })
      .andWhere("pet.deletedAt IS NULL")
      .groupBy("pet.gender")
      .getRawMany();

    return {
      total,
      byCategory: byCategory.reduce(
        (acc, item) => ({ ...acc, [item.categoryId]: parseInt(item.count) }),
        {},
      ),
      byGender: byGender.reduce(
        (acc, item) => ({ ...acc, [item.gender]: parseInt(item.count) }),
        {},
      ),
    };
  }

  // ========== 搜索功能 ==========

  async search(
    keyword: string,
    userId?: number,
    userRole?: string,
  ): Promise<Pet[]> {
    const queryBuilder = this.petRepository
      .createQueryBuilder("pet")
      .leftJoinAndSelect("pet.owner", "owner")
      .leftJoinAndSelect("pet.category", "category")
      .leftJoinAndSelect("pet.subCategory", "subCategory")
      .where("pet.deletedAt IS NULL")
      .andWhere("(pet.name LIKE :keyword OR pet.tags LIKE :keyword)", {
        keyword: `%${keyword}%`,
      });

    if (userRole === "USER") {
      queryBuilder.andWhere("pet.ownerId = :userId", { userId });
    }

    return queryBuilder.getMany();
  }

  // ========== 为 AI 问诊和诊断提供的查询方法 ==========

  async findByIds(ids: number[]): Promise<Pet[]> {
    return this.petRepository.find({
      where: { id: In(ids), deletedAt: null },
      relations: ["owner", "category", "subCategory"],
    });
  }

  async findByOwnerWithMedicalHistory(ownerId: number): Promise<Pet[]> {
    return this.petRepository.find({
      where: { ownerId, deletedAt: null },
      relations: ["category", "subCategory"],
      order: { createdAt: "DESC" },
      select: [
        "id",
        "name",
        "categoryId",
        "subCategoryId",
        "gender",
        "birthDate",
        "weight",
        "tags",
        "appointmentCount",
        "consultationCount",
      ],
    });
  }

  // 更新统计计数（当预约或问诊创建时调用）
  async incrementAppointmentCount(petId: number): Promise<void> {
    await this.petRepository.increment({ id: petId }, "appointmentCount", 1);
    await this.petRepository.update(petId, { lastAppointmentAt: new Date() });
  }

  async incrementConsultationCount(petId: number): Promise<void> {
    await this.petRepository.increment({ id: petId }, "consultationCount", 1);
  }

  // ========== 年龄计算 ==========

  calculateAge(birthDate: Date): string {
    if (!birthDate) return "未知";

    const today = new Date();
    const birth = new Date(birthDate);

    let years = today.getFullYear() - birth.getFullYear();
    let months = today.getMonth() - birth.getMonth();

    if (months < 0 || (months === 0 && today.getDate() < birth.getDate())) {
      years--;
      months += 12;
    }

    if (years < 1) {
      return `${months} 个月`;
    } else if (years < 2) {
      return `${years} 岁 ${months} 个月`;
    } else {
      return `${years} 岁`;
    }
  }

  // ========== 健康管理 ==========

  /**
   * 获取宠物健康统计
   * @param petId 宠物ID
   * @param userId 用户ID（用于权限验证）
   * @returns 健康统计数据
   */
  async getHealthStats(
    petId: number,
    userId?: number,
  ): Promise<{
    vaccine: {
      count: number;
      lastAt: Date | null;
      nextAt: Date | null;
      daysUntilNext: number | null;
    };
    deworming: {
      count: number;
      lastAt: Date | null;
      nextAt: Date | null;
      daysUntilNext: number | null;
    };
    checkup: {
      count: number;
      lastAt: Date | null;
      nextAt: Date | null;
      daysUntilNext: number | null;
    };
  }> {
    const pet = await this.petRepository.findOne({
      where: { id: petId, deletedAt: null },
    });

    if (!pet) {
      throw new NotFoundException("宠物不存在");
    }

    // 权限检查（如果提供了 userId）
    if (userId !== undefined && pet.ownerId !== userId) {
      throw new ForbiddenException("无权查看此宠物信息");
    }

    return {
      vaccine: {
        count: pet.vaccineCount || 0,
        lastAt: pet.lastVaccineAt,
        nextAt: pet.nextVaccineAt,
        daysUntilNext: this.calculateDaysUntil(pet.nextVaccineAt),
      },
      deworming: {
        count: pet.dewormingCount || 0,
        lastAt: pet.lastDewormingAt,
        nextAt: pet.nextDewormingAt,
        daysUntilNext: this.calculateDaysUntil(pet.nextDewormingAt),
      },
      checkup: {
        count: pet.checkupCount || 0,
        lastAt: pet.lastCheckupAt,
        nextAt: pet.nextCheckupAt,
        daysUntilNext: this.calculateDaysUntil(pet.nextCheckupAt),
      },
    };
  }

  /**
   * 更新宠物健康记录
   * 完成健康预约时自动调用，更新宠物的健康统计字段
   * @param petId 宠物ID
   * @param type 健康预约类型（疫苗、驱虫、体检）
   */
  async updateHealthRecord(petId: number, type: string): Promise<void> {
    const pet = await this.petRepository.findOne({
      where: { id: petId },
    });

    if (!pet) {
      return;
    }

    const today = new Date();

    switch (type) {
      case "VACCINE":
        pet.lastVaccineAt = today;
        pet.vaccineCount = (pet.vaccineCount || 0) + 1;
        break;

      case "DEWORMING":
        pet.lastDewormingAt = today;
        pet.dewormingCount = (pet.dewormingCount || 0) + 1;
        break;

      case "CHECKUP":
        pet.lastCheckupAt = today;
        pet.checkupCount = (pet.checkupCount || 0) + 1;
        break;
    }

    await this.petRepository.save(pet);
  }

  /**
   * 更新宠物健康记录（包含下次预约日期）
   * 完成健康预约时自动调用，更新宠物的健康统计字段和下次预约时间
   * @param petId 宠物ID
   * @param type 健康预约类型（vaccine、deworming、checkup）
   * @param nextAppointmentDate 下次预约日期（可选）
   * @param lastAppointmentDate 本次预约日期
   */
  async updateHealthRecordWithNextDate(
    petId: number,
    type: string,
    nextAppointmentDate?: Date,
    lastAppointmentDate?: Date,
  ): Promise<void> {
    const pet = await this.petRepository.findOne({
      where: { id: petId },
    });

    if (!pet) {
      return;
    }

    switch (type) {
      case "vaccine":
      case "VACCINE":
        if (nextAppointmentDate) {
          pet.nextVaccineAt = nextAppointmentDate;
        }
        if (lastAppointmentDate) {
          pet.lastVaccineAt = lastAppointmentDate;
        }
        pet.vaccineCount = (pet.vaccineCount || 0) + 1;
        break;

      case "deworming":
      case "DEWORMING":
        if (nextAppointmentDate) {
          pet.nextDewormingAt = nextAppointmentDate;
        }
        if (lastAppointmentDate) {
          pet.lastDewormingAt = lastAppointmentDate;
        }
        pet.dewormingCount = (pet.dewormingCount || 0) + 1;
        break;

      case "checkup":
      case "CHECKUP":
        if (nextAppointmentDate) {
          pet.nextCheckupAt = nextAppointmentDate;
        }
        if (lastAppointmentDate) {
          pet.lastCheckupAt = lastAppointmentDate;
        }
        pet.checkupCount = (pet.checkupCount || 0) + 1;
        break;
    }

    await this.petRepository.save(pet);
  }

  /**
   * 计算距离某天的天数
   * @param date 目标日期
   * @returns 距离天数（null 表示日期未设置）
   */
  private calculateDaysUntil(date: Date | null): number | null {
    if (!date) return null;

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const targetDate = new Date(date);
    targetDate.setHours(0, 0, 0, 0);

    const diffTime = targetDate.getTime() - today.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

    return diffDays;
  }

  // ========== 护理计划相关方法 ==========

  /**
   * 检测关键字段是否发生变化
   * @param pet 原宠物数据
   * @param updateData 更新数据
   * @returns 是否发生变化
   */
  private checkKeyFieldsChanged(pet: Pet, updateData: UpdatePetDto): boolean {
    const keyFields = [
      "weight",
      "isNeutered",
      "birthDate",
      "gender",
      "subCategoryId",
      "vaccineCount",
    ] as const;

    for (const field of keyFields) {
      // 日期字段在 DTO 中是字符串、实体中是 Date，需要先归一化再比较，
      // 否则同一天的数据也会被误判为变更，导致重复触发护理计划生成。
      if (
        updateData[field] !== undefined &&
        this.normalizeComparableValue(updateData[field]) !==
          this.normalizeComparableValue(pet[field])
      ) {
        return true;
      }
    }

    return false;
  }

  /**
   * 统一不同来源字段的比较格式
   * 将 Date、日期字符串、数字字符串分别归一化后再比较，
   * 避免把数据库返回的 decimal 字符串误判为日期，导致编辑宠物时抛出异常。
   * @param value 待比较的字段值
   * @returns 可直接用于比较的标准值
   */
  private normalizeComparableValue(
    value: unknown,
  ): string | number | boolean | null {
    if (value === undefined || value === null) {
      return null;
    }

    if (value instanceof Date) {
      return value.toISOString().slice(0, 10);
    }

    if (typeof value === "string") {
      const trimmedValue = value.trim();

      if (!trimmedValue) {
        return "";
      }

      const normalizedDate = this.normalizeDateString(trimmedValue);
      if (normalizedDate !== null) {
        return normalizedDate;
      }

      const normalizedNumber = this.normalizeNumericString(trimmedValue);
      if (normalizedNumber !== null) {
        return normalizedNumber;
      }

      return trimmedValue;
    }

    return value as number | boolean;
  }

  /**
   * 仅对明确属于日期格式的字符串做日期归一化，
   * 防止 weight 这类 decimal 字符串被错误送入 Date 构造函数。
   * @param value 待识别的字符串
   * @returns 标准日期字符串；如果不是日期格式则返回 null
   */
  private normalizeDateString(value: string): string | null {
    if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      return value;
    }

    /**
     * 只有明显包含日期分隔符或 ISO 时间标记的字符串才尝试按日期解析，
     * 这样可以避免把 "5.00"、"3" 之类的数值字符串误处理成日期。
     */
    const looksLikeDateString =
      value.includes("-") || value.includes("/") || value.includes("T");

    if (!looksLikeDateString) {
      return null;
    }

    const parsedDate = new Date(value);
    if (Number.isNaN(parsedDate.getTime())) {
      return null;
    }

    return parsedDate.toISOString().slice(0, 10);
  }

  /**
   * 将数值字符串归一化为 number，
   * 解决数据库 decimal 字段可能返回字符串而前端提交 number 的比较差异。
   * @param value 待识别的字符串
   * @returns 数值；如果不是有效数字则返回 null
   */
  private normalizeNumericString(value: string): number | null {
    const parsedNumber = Number(value);

    if (!Number.isFinite(parsedNumber)) {
      return null;
    }

    return parsedNumber;
  }

  /**
   * 触发护理计划生成
   * @param petId 宠物 ID
   */
  async triggerCarePlanGeneration(
    petId: number,
    options: { throwOnFailure?: boolean } = {},
  ) {
    try {
      // 1. 检查并取消上一次未完成的任务
      const pet = await this.petRepository.findOne({
        where: { id: petId },
        select: ["carePlanJobId", "carePlanStatus"],
      });

      if (pet?.carePlanJobId && pet?.carePlanStatus === "GENERATING") {
        try {
          const job = await this.carePlanQueue.getJob(pet.carePlanJobId);
          if (job && (await job.getState()) !== "completed") {
            await job.remove();
            this.logger.log(
              `[护理计划] 取消宠物 ${petId} 的旧任务: ${pet.carePlanJobId}`,
            );
          }
        } catch (error) {
          this.logger.warn(`[护理计划] 取消旧任务失败: ${error.message}`);
        }
      }

      // 2. 更新状态为"生成中"
      await this.petRepository.update(petId, {
        carePlanStatus: "GENERATING",
        carePlanJobId: null,
        carePlanError: null,
      });

      // 3. 获取宠物完整信息（含关联数据）
      const fullPet = await this.petRepository.findOne({
        where: { id: petId },
        relations: ["category", "subCategory", "owner"],
      });

      if (!fullPet) {
        this.logger.error(`[护理计划] 宠物 ${petId} 不存在`);
        return;
      }

      // 4. 构建 AI 请求参数
      const params = this.buildCarePlanParams(fullPet);

      // 5. 添加新任务到队列
      const job = await this.carePlanQueue.add(
        "generate",
        {
          petId,
          params,
        },
        {
          attempts: 3,
          backoff: {
            type: "fixed",
            delay: 5 * 60 * 1000,
          },
          timeout: 8 * 60 * 60 * 1000,
          removeOnComplete: false,
          removeOnFail: false,
        },
      );

      // 6. 保存 Job ID
      await this.petRepository.update(petId, {
        carePlanJobId: job.id.toString(),
      });

      this.logger.log(
        `[护理计划] 已为宠物 ${petId} 创建新的生成任务: ${job.id}`,
      );

      return {
        message: "护理计划生成任务已启动",
        data: {
          petId,
          status: "GENERATING",
          jobId: job.id.toString(),
        },
      };
    } catch (error) {
      this.logger.error(`[护理计划] 触发护理计划生成失败: ${error.message}`);

      // 更新状态为失败
      await this.petRepository.update(petId, {
        carePlanStatus: "FAILED",
        carePlanError: `触发生成失败: ${error.message}`,
      });

      if (options.throwOnFailure) {
        throw error;
      }
    }
  }

  /**
   * 构建宠物护理计划请求参数
   * @param pet 宠物信息（含关联数据）
   * @returns AI 接口请求参数
   */
  private buildCarePlanParams(pet: Pet): any {
    // 计算年龄
    const age = this.calculatePetAge(pet.birthDate);

    // 构建用户查询描述
    const userQuery = `我家有一只${age}的${pet.category?.name || ""}${pet.name || ""}，体重${pet.weight}公斤`;

    return {
      user_query: userQuery,
      pet_name: pet.name,
      pet_species: pet.category?.name, // 如：狗、猫
      pet_breed: pet.subCategory?.name, // 如：金毛、英短
      pet_age: age,
      pet_weight: parseFloat(pet.weight.toString()),
      pet_sex: pet.gender === PetGender.MALE ? "male" : "female",
      pet_neutered: pet.isNeutered,
    };
  }

  /**
   * 计算宠物年龄
   * @param birthDate 出生日期
   * @returns 年龄描述字符串
   */
  private calculatePetAge(birthDate: Date): string {
    if (!birthDate) return "年龄未知";

    const now = new Date();
    const diff = now.getTime() - new Date(birthDate).getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));

    if (days < 0) {
      return "出生日期异常";
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
}
