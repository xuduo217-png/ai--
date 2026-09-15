import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ChatPackage } from './entities/chat-package.entity';

@Injectable()
export class PackageService {
  constructor(
    @InjectRepository(ChatPackage)
    private packageRepository: Repository<ChatPackage>,
  ) {}

  async getAvailablePackages(doctorId?: number): Promise<ChatPackage[]> {
    const packages = await this.packageRepository
      .createQueryBuilder('pkg')
      .leftJoinAndSelect('pkg.config', 'config')
      .where('pkg.isActive = :isActive')
      .andWhere('(config.doctorId = :doctorId OR config.doctorId IS NULL)', {
        doctorId,
      })
      .orderBy('pkg.sortOrder', 'ASC')
      .getMany();

    return packages;
  }

  async findById(id: number): Promise<ChatPackage> {
    return this.packageRepository.findOne({ where: { id } });
  }

  async create(dto: any): Promise<ChatPackage> {
    const pkg = this.packageRepository.create(dto) as any;
    return this.packageRepository.save(pkg);
  }

  async update(id: number, dto: any): Promise<ChatPackage> {
    await this.packageRepository.update(id, dto);
    return this.packageRepository.findOne({ where: { id } });
  }

  async remove(id: number): Promise<void> {
    await this.packageRepository.delete(id);
  }
}
