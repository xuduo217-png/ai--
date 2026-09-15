import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Schedule } from './entities/schedule.entity';
import { CreateScheduleDto } from './dto/create-schedule.dto';
import { UpdateScheduleDto } from './dto/update-schedule.dto';

@Injectable()
export class SchedulesService {
  constructor(
    @InjectRepository(Schedule)
    private scheduleRepository: Repository<Schedule>,
  ) {}

  async create(createScheduleDto: CreateScheduleDto): Promise<Schedule> {
    const schedule = this.scheduleRepository.create(createScheduleDto);
    return this.scheduleRepository.save(schedule);
  }

  async findAll(doctorId?: number): Promise<Schedule[]> {
    const where = doctorId ? { doctorId } : {};
    return this.scheduleRepository.find({
      where,
      relations: ['doctor'],
      order: { date: 'ASC', period: 'ASC' },
    });
  }

  async findByDoctor(doctorId: number): Promise<Schedule[]> {
    return this.scheduleRepository.find({
      where: { doctorId },
      order: { date: 'ASC', period: 'ASC' },
    });
  }

  async findAvailableSlots(
    doctorId: number,
    date: string,
  ): Promise<Schedule[]> {
    return this.scheduleRepository.find({
      where: {
        doctorId,
        date: new Date(date),
        isAvailable: true,
      },
      order: { period: 'ASC' },
    });
  }

  async findOne(id: number): Promise<Schedule> {
    const schedule = await this.scheduleRepository.findOne({
      where: { id },
      relations: ['doctor'],
    });
    if (!schedule) {
      throw new NotFoundException('排班不存在');
    }
    return schedule;
  }

  async update(
    id: number,
    updateScheduleDto: UpdateScheduleDto,
  ): Promise<Schedule> {
    await this.scheduleRepository.update(id, updateScheduleDto);
    return this.findOne(id);
  }

  async remove(id: number): Promise<void> {
    await this.scheduleRepository.delete(id);
  }
}
