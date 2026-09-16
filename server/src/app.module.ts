import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ScheduleModule } from '@nestjs/schedule';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { RedisModule } from './redis/redis.module';
import { UsersModule } from './users/users.module';
import { AuthModule } from './auth/auth.module';
import { PetsModule } from './pets/pets.module';
import { PetCategoriesModule } from './pet-categories/pet-categories.module';
import { HospitalsModule } from './hospitals/hospitals.module';
import { DepartmentsModule } from './departments/departments.module';
import { DoctorsModule } from './doctors/doctors.module';
import { SchedulesModule } from './schedules/schedules.module';
import { AppointmentsModule } from './appointments/appointments.module';
import { ChatModule } from './chat/chat.module';
import { ShopModule } from './shop/shop.module';
import { ShopAdminModule } from './shop/admin/shop.admin.module';
import { AiSelfCheckModule } from './ai-self-check/ai-self-check.module';
import { AiDiagnosisReportModule } from './ai-diagnosis-report/ai-diagnosis-report.module';
import { UploadModule } from './upload/upload.module';
import { SmsModule } from './sms/sms.module';
import { SystemConfigsModule } from './system-configs/system-configs.module';
import { AuditModule } from './audit/audit.module';
import { PaymentModule } from './payment/payment.module';
import { AgentModule } from './agent/agent.module';
import { HealthArticlesModule } from './health-articles/health-articles.module';
import { AidGuidesModule } from './aid-guides/aid-guides.module';
import { AddressesModule } from './addresses/addresses.module';
import { HealthAppointmentsModule } from './health-appointments/health-appointments.module';
import { SeedModule } from './seeds/seed.module';
import { StatisticsModule } from './statistics/statistics.module';
import { FriendsModule } from './friends/friends.module';
import { CharityModule } from './charity/charity.module';
import { LostFoundModule } from './lost-found/lost-found.module';
import { ActivitiesModule } from './activities/activities.module';
import { NotificationsModule } from './notifications/notifications.module';
import { LogisticsModule } from './logistics/logistics.module';
import { CommunityModule } from './community/community.module';
import { NearbyModule } from './nearby/nearby.module';
import { ModerationModule } from './moderation/moderation.module';
import { MarketplaceChatModule } from './marketplace-chat/marketplace-chat.module';
import { createDatabaseOptions } from './config/database.config';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    ScheduleModule.forRoot(), // 启用定时任务模块
    RedisModule,
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) =>
        createDatabaseOptions(configService),
    }),
    UsersModule,
    AuthModule,
    PetsModule,
    PetCategoriesModule,
    HospitalsModule,
    DepartmentsModule,
    DoctorsModule,
    SchedulesModule,
    AppointmentsModule,
    ChatModule,
    ShopModule,
    ShopAdminModule, // 二手商品后台管理模块
    AiSelfCheckModule,
    AiDiagnosisReportModule,
    UploadModule,
    SmsModule,
    SystemConfigsModule,
    AuditModule,
    PaymentModule,
    AgentModule,
    HealthArticlesModule,
    AidGuidesModule,
    AddressesModule,
    HealthAppointmentsModule,
    SeedModule,
    StatisticsModule,
    FriendsModule,
    CharityModule,
    LostFoundModule,
    ActivitiesModule,
    NotificationsModule,
    LogisticsModule,
    CommunityModule,
    NearbyModule,
    ModerationModule,
    MarketplaceChatModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
