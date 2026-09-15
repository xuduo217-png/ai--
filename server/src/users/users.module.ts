import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { User } from './entities/user.entity';
import { Pet } from '../pets/entities/pet.entity';
import { HospitalsModule } from '../hospitals/hospitals.module';
import { PetsModule } from '../pets/pets.module';
import { SensitiveWordModule } from '../community/sensitive-word.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, Pet]),
    forwardRef(() => HospitalsModule),
    forwardRef(() => PetsModule),
    SensitiveWordModule,
  ],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
