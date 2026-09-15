import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AiSelfCheckController } from './ai-self-check.controller';
import { AiSelfCheckService } from './ai-self-check.service';
import { SelfCheckList, SelfCheckQuestion, SelfCheckOption } from './entities';
import { PetCategoriesModule } from '../pet-categories/pet-categories.module';
import { PetsModule } from '../pets/pets.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      SelfCheckList,
      SelfCheckQuestion,
      SelfCheckOption,
    ]),
    PetCategoriesModule,
    PetsModule,
  ],
  controllers: [AiSelfCheckController],
  providers: [AiSelfCheckService],
  exports: [AiSelfCheckService],
})
export class AiSelfCheckModule {}
