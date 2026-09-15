import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Department } from './entities/department.entity';
import { CreateDepartmentDto } from './dto/create-department.dto';
import { UpdateDepartmentDto } from './dto/update-department.dto';

/**
 * 科室服务类
 * 提供科室的 CRUD 操作，支持按医院筛选
 */
@Injectable()
export class DepartmentsService {
  constructor(
    @InjectRepository(Department)
    private departmentRepository: Repository<Department>,
  ) {}

  /**
   * 创建科室
   * @param createDepartmentDto 科室创建数据（必须包含 hospitalId）
   * @returns 创建的科室对象
   */
  async create(createDepartmentDto: CreateDepartmentDto): Promise<Department> {
    const department = this.departmentRepository.create(createDepartmentDto);
    return this.departmentRepository.save(department);
  }

  /**
   * 获取科室列表
   * @param hospitalId 医院ID（可选，用于筛选指定医院的科室）
   * @param activeOnly 是否只获取启用的科室
   * @returns 科室列表
   */
  async findAll(
    hospitalId?: number,
    activeOnly: boolean = false,
  ): Promise<Department[]> {
    const where: any = {};

    // 按医院筛选
    if (hospitalId) {
      where.hospitalId = hospitalId;
    }

    // 按状态筛选
    if (activeOnly) {
      where.isActive = true;
    }

    return this.departmentRepository.find({
      where,
      order: { createdAt: 'DESC' },
      relations: ['hospital'], // 关联查询医院信息
    });
  }

  /**
   * 获取科室详情
   * @param id 科室ID
   * @returns 科室对象，包含关联的医院信息
   */
  async findOne(id: number): Promise<Department> {
    const department = await this.departmentRepository.findOne({
      where: { id },
      relations: ['hospital'], // 关联查询医院信息
    });
    if (!department) {
      throw new NotFoundException('科室不存在');
    }
    return department;
  }

  /**
   * 更新科室信息
   * @param id 科室ID
   * @param updateDepartmentDto 更新数据
   * @returns 更新后的科室对象
   */
  async update(
    id: number,
    updateDepartmentDto: UpdateDepartmentDto,
  ): Promise<Department> {
    await this.departmentRepository.update(id, updateDepartmentDto);
    return this.findOne(id);
  }

  /**
   * 删除科室
   * @param id 科室ID
   */
  async remove(id: number): Promise<void> {
    await this.departmentRepository.delete(id);
  }
}
