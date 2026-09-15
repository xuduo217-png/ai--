import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BullModule } from '@nestjs/bull';
import { HttpModule } from '@nestjs/axios';
import { PetsService } from './pets.service';
import { PetsController } from './pets.controller';
import { Pet } from './entities/pet.entity';
import { PetCarePlanProcessor } from './processors/pet-care-plan.processor';
import { PET_CARE_PLAN_QUEUE } from './queues';

@Module({
  imports: [
    TypeOrmModule.forFeature([Pet]),
    BullModule.registerQueue({
      name: PET_CARE_PLAN_QUEUE,
    }),
    HttpModule,
  ],
  controllers: [PetsController],
  providers: [PetsService, PetCarePlanProcessor],
  exports: [PetsService],
})
export class PetsModule {}
