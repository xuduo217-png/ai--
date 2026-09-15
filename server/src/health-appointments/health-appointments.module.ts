import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HealthAppointmentsService } from './health-appointments.service';
import { HealthAppointmentsController } from './health-appointments.controller';
import { HealthAppointment } from './entities/health-appointment.entity';
import { PetsModule } from '../pets/pets.module';
import { HospitalsModule } from '../hospitals/hospitals.module';

/**
 * 健康预约模块
 * 提供健康预约（疫苗、驱虫、体检）的功能
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([HealthAppointment]),
    forwardRef(() => PetsModule),
    forwardRef(() => HospitalsModule),
  ],
  controllers: [HealthAppointmentsController],
  providers: [HealthAppointmentsService],
  exports: [HealthAppointmentsService],
})
export class HealthAppointmentsModule {}
