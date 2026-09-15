import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SensitiveWord } from './entities/sensitive-word.entity';
import { SensitiveWordService } from './sensitive-word.service';

@Module({
  imports: [TypeOrmModule.forFeature([SensitiveWord])],
  providers: [SensitiveWordService],
  exports: [SensitiveWordService],
})
export class SensitiveWordModule {}
