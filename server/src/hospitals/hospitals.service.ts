import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Hospital, HospitalStatus } from './entities/hospital.entity';
import { CreateHospitalDto } from './dto/create-hospital.dto';
import { UpdateHospitalDto } from './dto/update-hospital.dto';
import { QueryHospitalDto } from './dto/query-hospital.dto';
import { QueryNearbyHospitalsDto } from './dto/query-nearby-hospitals.dto';
import { NearbyHospitalResponseDto } from './dto/nearby-hospital-response.dto';
import { PaginatedResult } from '../common/dto/pagination.dto';
import { RedisService } from '../redis/redis.service';

@Injectable()
export class HospitalsService {
  private readonly logger = new Logger(HospitalsService.name);
  private readonly EARTH_RADIUS = 6371; // 地球半径（公里）
  private readonly CACHE_TTL = 3600; // 缓存时间（秒）- 1 小时

  constructor(
    @InjectRepository(Hospital)
    private hospitalRepository: Repository<Hospital>,
    private redisService: RedisService,
  ) {}

  async create(createHospitalDto: CreateHospitalDto): Promise<Hospital> {
    // 处理 isActive 字段：如果提供了 isActive，则设置 status
    const { isActive, businessHours, ...rest } = createHospitalDto;

    const hospital = this.hospitalRepository.create({
      ...rest,
      businessHours: businessHours || undefined,
      appointmentCount: 0,
      rating: 0,
      reviewCount: 0,
      status:
        isActive !== undefined
          ? isActive
            ? HospitalStatus.ACTIVE
            : HospitalStatus.INACTIVE
          : HospitalStatus.ACTIVE,
    });

    return this.hospitalRepository.save(hospital);
  }

  async findAll(query: QueryHospitalDto): Promise<PaginatedResult<Hospital>> {
    const {
      page = 1,
      pageSize = 10,
      sortOrder = 'DESC',
      sortBy = 'createdAt',
      name,
      city,
      province,
      status,
      minRating,
      maxRating,
    } = query;

    const queryBuilder = this.hospitalRepository
      .createQueryBuilder('hospital')
      .where('hospital.deletedAt IS NULL');

    if (name) {
      queryBuilder.andWhere('hospital.name LIKE :name', { name: `%${name}%` });
    }

    if (city) {
      queryBuilder.andWhere('hospital.city = :city', { city });
    }

    if (province) {
      queryBuilder.andWhere('hospital.province = :province', { province });
    }

    if (status) {
      queryBuilder.andWhere('hospital.status = :status', { status });
    }

    if (minRating !== undefined) {
      queryBuilder.andWhere('hospital.rating >= :minRating', { minRating });
    }

    if (maxRating !== undefined) {
      queryBuilder.andWhere('hospital.rating <= :maxRating', { maxRating });
    }

    const order = sortOrder === 'ASC' ? 'ASC' : 'DESC';
    queryBuilder.orderBy(`hospital.${sortBy}`, order);

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

  async findOne(id: number): Promise<Hospital> {
    const hospital = await this.hospitalRepository.findOne({
      where: { id, deletedAt: null },
    });

    if (!hospital) {
      throw new NotFoundException('医院不存在');
    }

    return hospital;
  }

  async update(
    id: number,
    updateHospitalDto: UpdateHospitalDto,
  ): Promise<Hospital> {
    // 处理 isActive 字段：如果提供了 isActive，则设置 status
    const { isActive, ...rest } = updateHospitalDto;
    const updateData: any = { ...rest };

    // 如果提供了 isActive，则设置 status
    if (isActive !== undefined) {
      updateData.status = isActive
        ? HospitalStatus.ACTIVE
        : HospitalStatus.INACTIVE;
    }

    await this.hospitalRepository.update(id, updateData);
    return this.findOne(id);
  }

  async remove(id: number): Promise<void> {
    await this.hospitalRepository.softDelete(id);
  }

  async incrementAppointmentCount(hospitalId: number): Promise<void> {
    await this.hospitalRepository.increment(
      { id: hospitalId },
      'appointmentCount',
      1,
    );
  }

  async getStatistics(hospitalId?: number): Promise<any> {
    const where = hospitalId
      ? { id: hospitalId, deletedAt: null }
      : { deletedAt: null };

    const total = await this.hospitalRepository.count({ where });

    const byStatus = await this.hospitalRepository
      .createQueryBuilder('hospital')
      .select('hospital.status', 'status')
      .addSelect('COUNT(*)', 'count')
      .where(hospitalId ? 'hospital.id = :hospitalId' : '1=1', { hospitalId })
      .andWhere('hospital.deletedAt IS NULL')
      .groupBy('hospital.status')
      .getRawMany();

    const byCity = await this.hospitalRepository
      .createQueryBuilder('hospital')
      .select('hospital.city', 'city')
      .addSelect('COUNT(*)', 'count')
      .where(hospitalId ? 'hospital.id = :hospitalId' : '1=1', { hospitalId })
      .andWhere('hospital.deletedAt IS NULL')
      .groupBy('hospital.city')
      .getRawMany();

    return {
      total,
      byStatus: byStatus.reduce(
        (acc, item) => ({ ...acc, [item.status]: parseInt(item.count) }),
        {},
      ),
      byCity: byCity.reduce(
        (acc, item) => ({ ...acc, [item.city]: parseInt(item.count) }),
        {},
      ),
    };
  }

  /**
   * 查询附近的医院
   * 使用 Haversine 公式计算距离，并按距离升序排序
   * 使用 Redis Geohash 缓存结果（1 小时）
   *
   * @param query 查询参数（经纬度、返回数量）
   * @returns 附近的医院列表（包含距离信息）
   */
  async getNearbyHospitals(
    query: QueryNearbyHospitalsDto,
  ): Promise<NearbyHospitalResponseDto[]> {
    const { latitude, longitude, limit = 10 } = query;

    // 生成简化的 Geohash（5位精度 ≈ 2.4km，用于缓存键）
    const geohash = this.encodeGeohash(latitude, longitude, 5);
    const cacheKey = `hospitals:nearby:${geohash}:${limit}`;

    try {
      // 尝试从 Redis 缓存获取
      const cached = await this.redisService.get(cacheKey);
      if (cached) {
        this.logger.log(`从缓存获取附近医院: ${cacheKey}`);
        return JSON.parse(cached);
      }
    } catch (error) {
      this.logger.error('读取 Redis 缓存失败:', error);
      // 继续执行，直接查询数据库
    }

    // 查询所有未删除的医院（只包含必要字段以提升性能）
    const hospitals = await this.hospitalRepository
      .createQueryBuilder('hospital')
      .select([
        'hospital.id',
        'hospital.name',
        'hospital.logo',
        'hospital.description',
        'hospital.province',
        'hospital.city',
        'hospital.county',
        'hospital.address',
        'hospital.phone',
        'hospital.email',
        'hospital.latitude',
        'hospital.longitude',
        'hospital.status',
        'hospital.rating',
        'hospital.reviewCount',
        'hospital.facilities',
      ])
      .where('hospital.deletedAt IS NULL')
      .andWhere('hospital.latitude IS NOT NULL')
      .andWhere('hospital.longitude IS NOT NULL')
      .getMany();

    // 计算每个医院的距离，并构建响应数据
    const hospitalsWithDistance = hospitals
      .map((hospital) => {
        const distance = this.calculateDistance(
          latitude,
          longitude,
          hospital.latitude,
          hospital.longitude,
        );

        return {
          id: hospital.id,
          name: hospital.name,
          logo: hospital.logo,
          description: hospital.description,
          province: hospital.province,
          city: hospital.city,
          county: hospital.county,
          address: hospital.address,
          phone: hospital.phone,
          email: hospital.email,
          latitude: hospital.latitude,
          longitude: hospital.longitude,
          status: hospital.status,
          businessStatusText: this.getBusinessStatusText(hospital.status),
          rating: hospital.rating,
          reviewCount: hospital.reviewCount,
          facilities: hospital.facilities,
          distance: Number(distance.toFixed(2)), // 保留两位小数
        };
      })
      .sort((a, b) => a.distance - b.distance) // 按距离升序排序
      .slice(0, limit); // 只返回前 N 条

    // 缓存结果到 Redis（1 小时）
    try {
      await this.redisService.set(
        cacheKey,
        JSON.stringify(hospitalsWithDistance),
        this.CACHE_TTL,
      );
      this.logger.log(`已缓存附近医院: ${cacheKey}`);
    } catch (error) {
      this.logger.error('写入 Redis 缓存失败:', error);
      // 缓存失败不影响返回结果
    }

    return hospitalsWithDistance;
  }

  /**
   * 使用 Haversine 公式计算两点之间的球面距离
   *
   * @param lat1 起点纬度
   * @param lon1 起点经度
   * @param lat2 终点纬度
   * @param lon2 终点经度
   * @returns 距离（单位：公里）
   */
  private calculateDistance(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
  ): number {
    // 将角度转换为弧度
    const toRad = (angle: number) => (angle * Math.PI) / 180;
    const φ1 = toRad(lat1);
    const φ2 = toRad(lat2);
    const Δφ = toRad(lat2 - lat1);
    const Δλ = toRad(lon2 - lon1);

    // Haversine 公式
    const a =
      Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
      Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    // 返回距离（单位：公里）
    return this.EARTH_RADIUS * c;
  }

  /**
   * 简化的 Geohash 编码（用于生成缓存键）
   * 将经纬度转换为整数编码，精度由位数决定
   *
   * @param latitude 纬度
   * @param longitude 经度
   * @param precision 精度位数（5 位 ≈ 2.4km）
   * @returns Geohash 字符串
   */
  private encodeGeohash(
    latitude: number,
    longitude: number,
    precision: number,
  ): string {
    // 简化实现：将经纬度转换为字符串表示
    // 使用整数部分和小数点后 precision 位
    const latStr = latitude.toFixed(precision);
    const lonStr = longitude.toFixed(precision);

    // 移除小数点，组合成字符串
    const latInt = latStr.replace('.', '').replace('-', '');
    const lonInt = lonStr.replace('.', '').replace('-', '');

    return `${latInt}_${lonInt}`;
  }

  /**
   * 根据医院状态返回友好的文本描述
   *
   * @param status 医院状态枚举
   * @returns 状态文本
   */
  private getBusinessStatusText(status: HospitalStatus): string {
    switch (status) {
      case HospitalStatus.ACTIVE:
        return '营业中';
      case HospitalStatus.INACTIVE:
        return '未营业';
      case HospitalStatus.SUSPENDED:
        return '暂停营业';
      default:
        return '未知状态';
    }
  }
}
