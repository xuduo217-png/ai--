import { Module, forwardRef, OnModuleInit } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { ModuleRef } from '@nestjs/core';
import { DoctorsService } from './doctors.service';
import { DoctorsController } from './doctors.controller';
import { DoctorsAuthController } from './doctors-auth.controller';
import { Doctor } from './entities/doctor.entity';
import { DoctorServiceItem } from './entities/doctor-service-item.entity';
import { HospitalsModule } from '../hospitals/hospitals.module';
import { DepartmentsModule } from '../departments/departments.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Doctor, DoctorServiceItem]),
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'your-secret-key',
      signOptions: { expiresIn: '7d' },
    }),
    forwardRef(() => HospitalsModule),
    forwardRef(() => DepartmentsModule),
  ],
  controllers: [DoctorsController, DoctorsAuthController],
  providers: [DoctorsService],
  exports: [DoctorsService],
})
export class DoctorsModule implements OnModuleInit {
  constructor(private readonly moduleRef: ModuleRef) {}

  onModuleInit() {
    // 将 ModuleRef 注入到 DoctorsService，用于延迟获取 ChatGateway
    const doctorsService = this.moduleRef.get<DoctorsService>(DoctorsService);
    doctorsService.setModuleRef(this.moduleRef);
  }
}
