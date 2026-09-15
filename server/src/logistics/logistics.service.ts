import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Logistics } from './entities/logistics.entity';
import { CreateLogisticsDto } from './dto/create-logistics.dto';
import { UpdateLogisticsDto } from './dto/update-logistics.dto';

/**
 * 物流管理服务
 */
@Injectable()
export class LogisticsService {
  constructor(
    @InjectRepository(Logistics)
    private logisticsRepository: Repository<Logistics>,
  ) {}

  /**
   * 获取物流列表（支持筛选）
   */
  async findAll(isEnabled?: boolean): Promise<Logistics[]> {
    const queryBuilder = this.logisticsRepository.createQueryBuilder(
      'logistics',
    );

    if (isEnabled !== undefined) {
      queryBuilder.andWhere('logistics.isEnabled = :isEnabled', {
        isEnabled,
      });
    }

    queryBuilder.orderBy('logistics.createdAt', 'DESC');

    return await queryBuilder.getMany();
  }

  /**
   * 获取启用的物流公司（用于下拉选择）
   */
  async findEnabled(): Promise<Logistics[]> {
    return await this.logisticsRepository.find({
      where: { isEnabled: true },
      order: { createdAt: 'DESC' },
    });
  }

  /**
   * 获取物流详情
   */
  async findOne(id: number): Promise<Logistics> {
    const logistics = await this.logisticsRepository.findOne({
      where: { id },
    });
    if (!logistics) {
      throw new NotFoundException(`物流公司（ID: ${id}）不存在`);
    }
    return logistics;
  }

  /**
   * 创建物流公司
   */
  async create(createDto: CreateLogisticsDto): Promise<Logistics> {
    // 检查编码是否已存在
    const existing = await this.logisticsRepository.findOne({
      where: { code: createDto.code },
    });
    if (existing) {
      throw new ConflictException(`物流编码 ${createDto.code} 已存在`);
    }

    const logistics = this.logisticsRepository.create(createDto);
    return await this.logisticsRepository.save(logistics);
  }

  /**
   * 更新物流公司
   */
  async update(id: number, updateDto: UpdateLogisticsDto): Promise<Logistics> {
    const logistics = await this.findOne(id);

    // 如果修改编码，检查新编码是否已存在
    if (updateDto.code && updateDto.code !== logistics.code) {
      const existing = await this.logisticsRepository.findOne({
        where: { code: updateDto.code },
      });
      if (existing) {
        throw new ConflictException(`物流编码 ${updateDto.code} 已存在`);
      }
    }

    Object.assign(logistics, updateDto);
    return await this.logisticsRepository.save(logistics);
  }

  /**
   * 删除物流公司
   */
  async remove(id: number): Promise<{ message: string }> {
    const logistics = await this.findOne(id);

    // TODO: 检查是否有订单正在使用该物流
    // const orderCount = await this.orderRepository.count({ where: { logisticsId: id } });
    // if (orderCount > 0) {
    //   throw new ConflictException('该物流公司正在使用中，无法删除');
    // }

    await this.logisticsRepository.remove(logistics);
    return { message: '删除成功' };
  }

  /**
   * 切换启用状态
   */
  async toggle(id: number): Promise<Logistics> {
    const logistics = await this.findOne(id);
    logistics.isEnabled = !logistics.isEnabled;
    return await this.logisticsRepository.save(logistics);
  }
}
