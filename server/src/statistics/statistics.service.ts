import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Hospital, HospitalStatus } from '../hospitals/entities/hospital.entity';
import { Doctor } from '../doctors/entities/doctor.entity';
import { User } from '../users/entities/user.entity';
import { Pet } from '../pets/entities/pet.entity';

/**
 * 统计数据服务
 * 提供各类统计数据的查询功能
 */
@Injectable()
export class StatisticsService {
  constructor(
    @InjectRepository(Hospital)
    private readonly hospitalRepository: Repository<Hospital>,
    @InjectRepository(Doctor)
    private readonly doctorRepository: Repository<Doctor>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Pet)
    private readonly petRepository: Repository<Pet>,
  ) {}

  /**
   * 获取首页统计数据
   * 返回医院、医生、用户、宠物的总数
   */
  async getDashboardStats() {
    // 并行查询所有统计数据，提高性能
    const [
      hospitalsCount,
      doctorsCount,
      usersCount,
      petsCount,
    ] = await Promise.all([
      // Hospital 使用 status 字段（枚举值：active/inactive/suspended）
      this.hospitalRepository.count({ where: { status: HospitalStatus.ACTIVE } }),
      // Doctor 使用 isActive 字段
      this.doctorRepository.count({ where: { isActive: true } }),
      // User 使用 isActive 字段
      this.userRepository.count({ where: { isActive: true } }),
      // Pet 统计所有记录
      this.petRepository.count(),
    ]);

    return {
      hospitals: hospitalsCount,
      doctors: doctorsCount,
      users: usersCount,
      pets: petsCount,
    };
  }
}
