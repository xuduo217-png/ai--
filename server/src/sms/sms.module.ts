import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SmsService } from './sms.service';
import { SmsController } from './sms.controller';
import { SmsRecord } from './entities/sms-record.entity';

@Module({
  imports: [ConfigModule, TypeOrmModule.forFeature([SmsRecord])],
  providers: [SmsService],
  controllers: [SmsController],
  exports: [SmsService],
})
export class SmsModule {}
