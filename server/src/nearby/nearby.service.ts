import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserLocation } from './entities/user-location.entity';
import { User } from '../users/entities/user.entity';
import { Friendship } from '../friends/entities/friendship.entity';
import { Pet } from '../pets/entities/pet.entity';
import {
  GetNearbyUsersDto,
  UpdateLocationDto,
  NearbyUserDto,
  LocationSettingsDto,
  ToggleDiscoveryDto,
} from './dto/nearby.dto';

/**
 * 附近的人服务
 *
 * 核心功能：
 * - Haversine 距离计算
 * - 附近用户查询（支持距离筛选、分页）
 * - 位置更新
 * - 发现开关控制
 */
@Injectable()
export class NearbyService {
  constructor(
    @InjectRepository(UserLocation)
    private userLocationRepository: Repository<UserLocation>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(Friendship)
    private friendshipRepository: Repository<Friendship>,
    @InjectRepository(Pet)
    private petRepository: Repository<Pet>,
  ) {}

  /**
   * Haversine 公式计算两点间距离（米）
   *
   * @param lat1 纬度1
   * @param lon1 经度1
   * @param lat2 纬度2
   * @param lon2 经度2
   * @returns 距离（米）
   */
  private calculateDistance(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
  ): number {
    const R = 6371e3; // 地球半径（米）
    const φ1 = (lat1 * Math.PI) / 180;
    const φ2 = (lat2 * Math.PI) / 180;
    const Δφ = ((lat2 - lat1) * Math.PI) / 180;
    const Δλ = ((lon2 - lon1) * Math.PI) / 180;

    const a =
      Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
      Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c;
  }

  /**
   * 获取附近的人列表
   *
   * 实现要点：
   * 1. 使用 Haversine 公式计算距离
   * 2. 排除当前用户自己
   * 3. 只返回 discovery_enabled = true 的用户
   * 4. 按距离升序排序
   * 5. 检查好友关系
   * 6. 获取宠物类型标签
   * 7. 获取最后活跃时间
   */
  async getNearbyUsers(
    userId: number,
    dto: GetNearbyUsersDto,
  ): Promise<{
    data: NearbyUserDto[];
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  }> {
    const latitude = Number(dto.latitude);
    const longitude = Number(dto.longitude);
    const radius = Number.isFinite(Number(dto.radius))
      ? Math.min(100000, Math.max(0, Number(dto.radius)))
      : 5000;
    const page = Number.isFinite(Number(dto.page))
      ? Math.max(1, Math.floor(Number(dto.page)))
      : 1;
    const pageSize = Number.isFinite(Number(dto.pageSize))
      ? Math.min(100, Math.max(1, Math.floor(Number(dto.pageSize))))
      : 20;

    if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
      throw new BadRequestException('latitude 参数不合法');
    }

    if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
      throw new BadRequestException('longitude 参数不合法');
    }

    const activeSince = new Date(Date.now() - 24 * 60 * 60 * 1000);

    // 查询所有开启发现的用户位置（排除自己）
    const userLocations = await this.userLocationRepository
      .createQueryBuilder('location')
      .leftJoinAndSelect('location.user', 'user')
      .where('location.discoveryEnabled = :discoveryEnabled', { discoveryEnabled: true })
      .andWhere('location.updatedAt >= :activeSince', { activeSince })
      .andWhere('NOT (location.latitude = 0 AND location.longitude = 0)')
      .getMany();

    // 计算距离并筛选
    const nearbyUsers = userLocations
      .filter((loc) => loc.userId !== userId) // 排除自己
      .map((loc) => {
        const distance = this.calculateDistance(
          latitude,
          longitude,
          parseFloat(loc.latitude.toString()),
          parseFloat(loc.longitude.toString()),
        );

        return {
          ...loc,
          distance,
        };
      })
      .filter((item) => {
        // 距离筛选：0 表示同城（不限距离）
        if (radius === 0) return true;
        return item.distance <= radius;
      })
      .sort((a, b) => a.distance - b.distance); // 按距离升序

    // 分页
    const total = nearbyUsers.length;
    const totalPages = Math.ceil(total / pageSize);
    const offset = (page - 1) * pageSize;
    const paginatedUsers = nearbyUsers.slice(offset, offset + pageSize);

    // 获取好友关系、宠物类型、最后活跃时间
    const userIds = paginatedUsers.map((u) => u.userId);

    if (userIds.length === 0) {
      return {
        data: [],
        total,
        page,
        limit: pageSize,
        totalPages,
      };
    }

    // 查询好友关系
    const friendships = await this.friendshipRepository
      .createQueryBuilder('f')
      .where('f.userId = :userId', { userId })
      .orWhere('f.friendId = :userId', { userId })
      .getMany();

    const friendIds = new Set(
      friendships.map((f) =>
        f.userId === userId ? f.friendId : f.userId,
      ),
    );

    // 查询宠物类型
    const pets = await this.petRepository
      .createQueryBuilder('p')
      .leftJoinAndSelect('p.category', 'category')
      .where('p.ownerId IN (:...userIds)', { userIds })
      .andWhere('p.deletedAt IS NULL')
      .getMany();

    const userPetTypes: Record<number, string[]> = {};
    pets.forEach((pet) => {
      const typeName = pet.category?.name;
      if (!typeName) {
        return;
      }

      if (!userPetTypes[pet.ownerId]) {
        userPetTypes[pet.ownerId] = [];
      }
      if (!userPetTypes[pet.ownerId].includes(typeName)) {
        userPetTypes[pet.ownerId].push(typeName);
      }
    });

    // 组装返回数据
    const data: NearbyUserDto[] = await Promise.all(
      paginatedUsers.map(async (item) => {
        const user = item.user;

        // 获取最后活跃时间（使用 updatedAt 作为参考）
        let lastActiveAt: Date | undefined = undefined;
        if (user.updatedAt) {
          lastActiveAt = user.updatedAt;
        }

        return {
          userId: item.userId,
          username: user.username || user.phone || '未知用户',
          avatar: user.avatar,
          signature: undefined, // User 实体暂无 signature 字段，后续可扩展
          distance: Math.round(item.distance), // 四舍五入到整数
          lastActiveAt,
          petTypes: userPetTypes[item.userId] || [],
          isFriend: friendIds.has(item.userId),
        };
      }),
    );

    return {
      data,
      total,
      page,
      limit: pageSize,
      totalPages,
    };
  }

  /**
   * 更新用户位置
   *
   * 使用 INSERT ... ON DUPLICATE KEY UPDATE 实现 upsert
   */
  async updateLocation(userId: number, dto: UpdateLocationDto) {
    const { latitude, longitude, city } = dto;

    // 检查用户是否存在
    const user = await this.userRepository.findOne({
      where: { id: userId },
    });
    if (!user) {
      throw new NotFoundException('用户不存在');
    }

    // 查找现有位置记录
    let location = await this.userLocationRepository.findOne({
      where: { user: { id: userId } },
    });

    if (location) {
      // 更新现有记录
      location.latitude = latitude;
      location.longitude = longitude;
      if (city !== undefined) {
        location.city = city;
      }
      location.discoveryEnabled = location.discoveryEnabled ?? true; // 保持原有设置
      await this.userLocationRepository.save(location);
    } else {
      // 创建新记录
      location = this.userLocationRepository.create({
        user: { id: userId }, // 注意：必须设置 user 关系对象，不能直接设置 userId
        latitude,
        longitude,
        city: city ?? null,
        discoveryEnabled: true, // 默认开启发现
      });
      await this.userLocationRepository.save(location);
    }

    return {
      success: true,
      message: '位置更新成功',
    };
  }

  /**
   * 获取用户位置设置
   */
  async getLocationSettings(userId: number): Promise<LocationSettingsDto> {
    const location = await this.userLocationRepository.findOne({
      where: { user: { id: userId } },
    });

    if (!location) {
      // 未设置过位置，返回默认值
      return {
        discoveryEnabled: true,
        currentLocation: undefined,
      };
    }

    const latitude = parseFloat(location.latitude.toString());
    const longitude = parseFloat(location.longitude.toString());
    const hasValidLocation = !(latitude === 0 && longitude === 0);

    return {
      discoveryEnabled: location.discoveryEnabled ?? true,
      currentLocation: hasValidLocation
        ? {
            latitude,
            longitude,
            city: location.city,
            updatedAt: location.updatedAt,
          }
        : undefined,
    };
  }

  /**
   * 切换发现开关
   */
  async toggleDiscovery(
    userId: number,
    dto: ToggleDiscoveryDto,
  ): Promise<{ success: boolean; discoveryEnabled: boolean }> {
    const { enabled } = dto;

    // 查找现有位置记录
    let location = await this.userLocationRepository.findOne({
      where: { user: { id: userId } },
    });

    if (location) {
      // 更新现有记录
      location.discoveryEnabled = enabled;
      await this.userLocationRepository.save(location);
    } else {
      // 开启发现且没有历史位置时，沿用默认开启（不创建 0,0 占位坐标）
      if (enabled) {
        return {
          success: true,
          discoveryEnabled: true,
        };
      }

      // 关闭发现且没有历史位置时，创建占位记录以持久化隐私开关
      location = this.userLocationRepository.create({
        user: { id: userId }, // 注意：必须设置 user 关系对象，不能直接设置 userId
        latitude: 0,
        longitude: 0,
        discoveryEnabled: false,
      });
      await this.userLocationRepository.save(location);
    }

    return {
      success: true,
      discoveryEnabled: enabled,
    };
  }

  /**
   * 清理过期位置数据（定时任务）
   *
   * 删除超过 24 小时未更新的位置数据
   */
  async cleanupExpiredLocations() {
    const expiredDate = new Date();
    expiredDate.setHours(expiredDate.getHours() - 24);

    const result = await this.userLocationRepository
      .createQueryBuilder('location')
      .delete()
      .where('location.updatedAt < :expiredDate', { expiredDate })
      .execute();

    console.log(`[NearbyService] 清理过期位置数据: ${result.affected} 条`);
    return result.affected;
  }
}
