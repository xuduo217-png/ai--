import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { PetCategoriesService } from "./pet-categories.service";
import { PetCategoriesController } from "./pet-categories.controller";
import { PetCategory } from "./entities/pet-category.entity";
import { Pet } from "../pets/entities/pet.entity";

@Module({
  imports: [TypeOrmModule.forFeature([PetCategory, Pet])],
  controllers: [PetCategoriesController],
  providers: [PetCategoriesService],
  exports: [PetCategoriesService],
})
export class PetCategoriesModule {}
