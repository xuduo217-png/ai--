import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { In, IsNull, LessThan, Repository } from "typeorm";
import { AiDiagnosisReport } from "../ai-diagnosis-report/entities/ai-diagnosis-report.entity";
import { HealthAppointment } from "../health-appointments/entities/health-appointment.entity";
import { Pet } from "../pets/entities/pet.entity";
import { User } from "../users/entities/user.entity";
import { ChatSession, SessionStatus } from "./entities/chat-session.entity";
import { Message, MessageType } from "./entities/message.entity";

@Injectable()
export class DoctorPatientRecordService {
  constructor(
    @InjectRepository(ChatSession)
    private readonly chatSessionRepository: Repository<ChatSession>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Pet)
    private readonly petRepository: Repository<Pet>,
    @InjectRepository(AiDiagnosisReport)
    private readonly reportRepository: Repository<AiDiagnosisReport>,
    @InjectRepository(HealthAppointment)
    private readonly appointmentRepository: Repository<HealthAppointment>,
    @InjectRepository(Message)
    private readonly messageRepository: Repository<Message>,
  ) {}

  async getPatient(conversationId: string, doctorId: number) {
    const session = await this.assertDoctorSession(conversationId, doctorId);
    const [user, pets] = await Promise.all([
      this.userRepository.findOne({ where: { id: session.userId } }),
      this.petRepository.find({
        where: { ownerId: session.userId, deletedAt: IsNull() },
        relations: ["category", "subCategory"],
        order: { createdAt: "DESC" },
      }),
    ]);

    if (!user) {
      throw new NotFoundException("会话用户不存在");
    }

    return {
      user: {
        id: user.id,
        name: user.username || "用户",
        avatar: user.avatar || "",
      },
      petCount: pets.length,
      pets: pets.map((pet) => this.toPetRecord(pet)),
    };
  }

  async getAiReports(
    conversationId: string,
    doctorId: number,
    petId: number,
    page: number,
    pageSize: number,
  ) {
    const session = await this.assertDoctorSession(conversationId, doctorId);
    await this.assertPatientPet(session.userId, petId);

    const [reports, total] = await this.reportRepository.findAndCount({
      where: {
        userId: session.userId,
        petId,
        isDeleted: false,
      },
      order: { createdAt: "DESC" },
      skip: (page - 1) * pageSize,
      take: pageSize,
    });

    return {
      data: reports.map((report) => this.toAiReport(report, false)),
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  async getAiReport(
    conversationId: string,
    doctorId: number,
    reportId: number,
  ) {
    const session = await this.assertDoctorSession(conversationId, doctorId);
    const report = await this.reportRepository.findOne({
      where: {
        id: reportId,
        userId: session.userId,
        isDeleted: false,
      },
    });

    if (!report) {
      throw new NotFoundException("AI 问诊报告不存在");
    }
    await this.assertPatientPet(session.userId, report.petId);
    return this.toAiReport(report, true);
  }

  async getAppointments(
    conversationId: string,
    doctorId: number,
    petId: number,
    page: number,
    pageSize: number,
  ) {
    const session = await this.assertDoctorSession(conversationId, doctorId);
    await this.assertPatientPet(session.userId, petId);

    const [appointments, total] = await this.appointmentRepository.findAndCount(
      {
        where: {
          userId: session.userId,
          petId,
          deletedAt: IsNull(),
        },
        relations: ["hospital", "doctor"],
        order: { appointmentDate: "DESC", createdAt: "DESC" },
        skip: (page - 1) * pageSize,
        take: pageSize,
      },
    );

    return {
      data: appointments.map((appointment) => this.toAppointment(appointment)),
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  async getAppointment(
    conversationId: string,
    doctorId: number,
    appointmentId: number,
  ) {
    const session = await this.assertDoctorSession(conversationId, doctorId);
    const appointment = await this.appointmentRepository.findOne({
      where: {
        id: appointmentId,
        userId: session.userId,
        deletedAt: IsNull(),
      },
      relations: ["hospital", "doctor"],
    });

    if (!appointment) {
      throw new NotFoundException("预约不存在");
    }
    await this.assertPatientPet(session.userId, appointment.petId);
    return this.toAppointment(appointment);
  }

  async getCarePlan(conversationId: string, doctorId: number, petId: number) {
    const session = await this.assertDoctorSession(conversationId, doctorId);
    const pet = await this.assertPatientPet(session.userId, petId);
    return {
      ...this.toPetRecord(pet),
      carePlan: pet.carePlan || null,
      carePlanStatus: pet.carePlanStatus || "NOT_GENERATED",
      carePlanGeneratedAt: pet.carePlanGeneratedAt || null,
      carePlanError: pet.carePlanError || "",
    };
  }

  async getHistory(
    conversationId: string,
    doctorId: number,
    page: number,
    pageSize: number,
  ) {
    const currentSession = await this.assertDoctorSession(
      conversationId,
      doctorId,
    );
    const [sessions, total] = await this.chatSessionRepository.findAndCount({
      where: {
        id: LessThan(currentSession.id),
        userId: currentSession.userId,
        doctorId,
        status: In([SessionStatus.PAID, SessionStatus.EXPIRED]),
      },
      relations: ["order", "order.serviceItem"],
      order: { id: "DESC" },
      skip: (page - 1) * pageSize,
      take: pageSize,
    });

    if (sessions.length === 0) {
      return {
        data: [],
        total,
        page,
        pageSize,
        totalPages: Math.ceil(total / pageSize),
      };
    }

    const conversationIds = sessions.map((session) => session.conversationId);
    const [countRows, lastMessages] = await Promise.all([
      this.messageRepository
        .createQueryBuilder("message")
        .select("message.conversationId", "conversationId")
        .addSelect("COUNT(message.id)", "messageCount")
        .where("message.conversationId IN (:...conversationIds)", {
          conversationIds,
        })
        .andWhere("message.isDeleted = :isDeleted", { isDeleted: false })
        .groupBy("message.conversationId")
        .getRawMany<{ conversationId: string; messageCount: string }>(),
      this.messageRepository
        .createQueryBuilder("message")
        .where("message.conversationId IN (:...conversationIds)", {
          conversationIds,
        })
        .andWhere("message.isDeleted = :isDeleted", { isDeleted: false })
        .andWhere(
          `message.id = (
            SELECT latest.id
            FROM messages latest
            WHERE latest.conversationId = message.conversationId
              AND latest.isDeleted = :isDeleted
            ORDER BY latest.createdAt DESC, latest.id DESC
            LIMIT 1
          )`,
        )
        .getMany(),
    ]);
    const messageCounts = new Map(
      countRows.map((row) => [row.conversationId, Number(row.messageCount)]),
    );
    const lastMessagesByConversation = new Map(
      lastMessages.map((message) => [message.conversationId, message]),
    );

    return {
      data: sessions.map((session) => {
        const lastMessage = lastMessagesByConversation.get(
          session.conversationId,
        );
        return {
          id: session.id,
          conversationId: session.conversationId,
          status: session.status,
          orderId: session.orderId,
          serviceItemName: session.order?.serviceItem?.name || "在线咨询",
          serviceStartAt: session.serviceStartAt,
          serviceEndAt: session.serviceEndAt,
          createdAt: session.createdAt,
          lastMessageAt: lastMessage?.createdAt || session.lastMessageAt,
          messageCount: messageCounts.get(session.conversationId) || 0,
          lastMessage: lastMessage ? this.toHistoryMessage(lastMessage) : null,
        };
      }),
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  async getHistoryMessages(
    conversationId: string,
    historyConversationId: string,
    doctorId: number,
    page: number,
    pageSize: number,
  ) {
    await this.assertHistorySession(
      conversationId,
      historyConversationId,
      doctorId,
    );
    const [messages, total] = await this.messageRepository.findAndCount({
      where: { conversationId: historyConversationId, isDeleted: false },
      order: { createdAt: "DESC", id: "DESC" },
      skip: (page - 1) * pageSize,
      take: pageSize,
    });

    return {
      data: messages.reverse().map((message) => this.toHistoryMessage(message)),
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  private async assertDoctorSession(
    conversationId: string,
    doctorId: number,
  ): Promise<ChatSession> {
    const session = await this.chatSessionRepository.findOne({
      where: { conversationId },
    });

    if (!session) {
      throw new NotFoundException("咨询会话不存在");
    }
    if (session.doctorId !== doctorId) {
      throw new ForbiddenException("无权查看该咨询用户的健康档案");
    }
    return session;
  }

  private async assertHistorySession(
    conversationId: string,
    historyConversationId: string,
    doctorId: number,
  ): Promise<ChatSession> {
    const currentSession = await this.assertDoctorSession(
      conversationId,
      doctorId,
    );
    const historySession = await this.chatSessionRepository.findOne({
      where: { conversationId: historyConversationId },
    });
    const isPersistedHistory =
      historySession?.status === SessionStatus.PAID ||
      historySession?.status === SessionStatus.EXPIRED;
    if (
      !historySession ||
      historySession.id >= currentSession.id ||
      historySession.userId !== currentSession.userId ||
      historySession.doctorId !== doctorId ||
      !isPersistedHistory
    ) {
      throw new NotFoundException("历史咨询不存在");
    }
    return historySession;
  }

  private async assertPatientPet(userId: number, petId: number): Promise<Pet> {
    const pet = await this.petRepository.findOne({
      where: { id: petId, ownerId: userId, deletedAt: IsNull() },
    });
    if (!pet) {
      throw new NotFoundException("用户宠物不存在");
    }
    return pet;
  }

  private toPetRecord(pet: Pet) {
    const vaccine = {
      count: pet.vaccineCount || 0,
      lastAt: pet.lastVaccineAt || null,
      nextAt: pet.nextVaccineAt || null,
    };
    const deworming = {
      count: pet.dewormingCount || 0,
      lastAt: pet.lastDewormingAt || null,
      nextAt: pet.nextDewormingAt || null,
    };
    const checkup = {
      count: pet.checkupCount || 0,
      lastAt: pet.lastCheckupAt || null,
      nextAt: pet.nextCheckupAt || null,
    };
    return {
      id: pet.id,
      name: pet.name,
      avatar: pet.avatar || "",
      categoryId: pet.categoryId,
      subCategoryId: pet.subCategoryId,
      category: pet.category
        ? { id: pet.category.id, name: pet.category.name }
        : null,
      subCategory: pet.subCategory
        ? { id: pet.subCategory.id, name: pet.subCategory.name }
        : null,
      gender: pet.gender,
      birthDate: pet.birthDate,
      weight: pet.weight,
      isNeutered: pet.isNeutered,
      vaccineCount: pet.vaccineCount || 0,
      ownerId: pet.ownerId,
      createdAt: pet.createdAt,
      updatedAt: pet.updatedAt,
      vaccination: vaccine,
      healthStats: { vaccine, deworming, checkup },
    };
  }

  private toHistoryMessage(message: Message) {
    const isRevoked = message.isRevoked === true;
    return {
      id: message.id,
      conversationId: message.conversationId,
      senderId: message.senderId,
      senderType: message.senderType,
      receiverId: message.receiverId,
      receiverType: message.receiverType,
      content: isRevoked ? "消息已撤回" : message.content,
      type: isRevoked ? MessageType.TEXT : message.type,
      isAutoReply: message.isAutoReply,
      isRead: message.isRead,
      isRevoked: message.isRevoked,
      packages: isRevoked ? [] : message.packages,
      orderId: message.orderId,
      createdAt: message.createdAt,
    };
  }

  private toAiReport(report: AiDiagnosisReport, includeDetail: boolean) {
    return {
      id: report.id,
      petId: report.petId,
      status: report.status,
      symptoms: report.symptoms,
      diagnosisImages: report.diagnosisImages || [],
      basicInfo: report.basicInfo || {},
      ...(includeDetail
        ? {
            selfCheckSnapshot: report.selfCheckSnapshot,
            westernDiagnosis: report.westernDiagnosis,
            tcmDiagnosis: report.tcmDiagnosis,
            petSnapshot: report.petSnapshot,
          }
        : {}),
      errorMessage: report.errorMessage || "",
      createdAt: report.createdAt,
      updatedAt: report.updatedAt,
      completedAt: report.completedAt || null,
    };
  }

  private toAppointment(appointment: HealthAppointment) {
    return {
      id: appointment.id,
      type: appointment.type,
      status: appointment.status,
      appointmentDate: appointment.appointmentDate,
      timeSlot: appointment.timeSlot,
      petId: appointment.petId,
      hospitalId: appointment.hospitalId,
      doctorId: appointment.doctorId || null,
      notes: appointment.notes || "",
      operationContent: appointment.operationContent || "",
      detailContent: appointment.detailContent || "",
      createdAt: appointment.createdAt,
      updatedAt: appointment.updatedAt,
      hospital: appointment.hospital
        ? {
            id: appointment.hospital.id,
            name: appointment.hospital.name,
            address: appointment.hospital.address || "",
            phone: appointment.hospital.phone || "",
            logo: appointment.hospital.logo || "",
          }
        : null,
      doctor: appointment.doctor
        ? { id: appointment.doctor.id, name: appointment.doctor.name }
        : null,
    };
  }
}
