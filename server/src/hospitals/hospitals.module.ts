import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HospitalsService } from './hospitals.service';
import { HospitalsController } from './hospitals.controller';
import { Hospital } from './entities/hospital.entity';
import { RedisModule } from '../redis/redis.module';

@Module({
  imports: [TypeOrmModule.forFeature([Hospital]), RedisModule],
  controllers: [HospitalsController],
  providers: [HospitalsService],
  exports: [HospitalsService, TypeOrmModule],
})
export class HospitalsModule {}
