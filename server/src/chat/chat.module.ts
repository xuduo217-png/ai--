import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { ChatService } from "./chat.service";
import { ChatController } from "./chat.controller";
import { ChatGateway } from "./chat.gateway";
import { ChatSessionService } from "./chat-session.service";
import { AutoReplyService } from "./auto-reply.service";
import { PackageService } from "./package.service";
import { OrderService } from "./order.service";
import { PaymentConfigService } from "./payment-config.service";
import { Message } from "./entities/message.entity";
import { ChatSession } from "./entities/chat-session.entity";
import { AutoReply } from "./entities/auto-reply.entity";
import { ChatPaymentConfig } from "./entities/chat-payment-config.entity";
import { ChatPackage } from "./entities/chat-package.entity";
import { ChatOrder } from "./entities/chat-order.entity";
import { ChatSessionExtension } from "./entities/chat-session-extension.entity";
import { DoctorsModule } from "../doctors/doctors.module";
import { UsersModule } from "../users/users.module";
import { UploadModule } from "../upload/upload.module";
import { CommunityModule } from "../community/community.module";
import { JwtModule } from "@nestjs/jwt";
import { AuthModule } from "../auth/auth.module";
import { AiDiagnosisReport } from "../ai-diagnosis-report/entities/ai-diagnosis-report.entity";
import { HealthAppointment } from "../health-appointments/entities/health-appointment.entity";
import { Pet } from "../pets/entities/pet.entity";
import { User } from "../users/entities/user.entity";
import { DoctorPatientRecordService } from "./doctor-patient-record.service";
import { PaymentModule } from "../payment/payment.module";
import { CHAT_PAYMENT_FULFILLER } from "../payment/chat-payment-fulfiller";
import { ChatSessionExtensionService } from "./chat-session-extension.service";

@Module({
  imports: [
    DoctorsModule,
    UsersModule,
    UploadModule,
    AuthModule,
    CommunityModule, // 导入社区模块以使用 SensitiveWordService
    PaymentModule,
    JwtModule.register({}),
    TypeOrmModule.forFeature([
      Message,
      ChatSession,
      AutoReply,
      ChatPaymentConfig,
      ChatPackage,
      ChatOrder,
      ChatSessionExtension,
      User,
      Pet,
      AiDiagnosisReport,
      HealthAppointment,
    ]),
  ],
  controllers: [ChatController],
  providers: [
    ChatService,
    ChatGateway,
    ChatSessionService,
    AutoReplyService,
    PackageService,
    OrderService,
    {
      provide: CHAT_PAYMENT_FULFILLER,
      useExisting: OrderService,
    },
    PaymentConfigService,
    DoctorPatientRecordService,
    ChatSessionExtensionService,
  ],
  exports: [ChatService, ChatGateway, ChatSessionService],
})
export class ChatModule {}
