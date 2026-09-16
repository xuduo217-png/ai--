import { ForbiddenException, Injectable } from "@nestjs/common";
import { randomUUID } from "crypto";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { Pet } from "../pets/entities/pet.entity";
import { PetsService } from "../pets/pets.service";
import { RouteAgentMessageDto } from "./dto/route-agent-message.dto";
import { AgentMessage } from "./entities/agent-message.entity";
import { AgentSession } from "./entities/agent-session.entity";

export type AgentIntent =
  "HEALTH" | "SHOP" | "APPOINTMENT" | "COMMUNITY" | "ORDER";

@Injectable()
export class AgentService {
  constructor(
    private readonly petsService: PetsService,
    @InjectRepository(AgentSession)
    private readonly sessionRepository: Repository<AgentSession>,
    @InjectRepository(AgentMessage)
    private readonly messageRepository: Repository<AgentMessage>,
  ) {}

  async getHome(userId: number) {
    const pets = await this.petsService.findByOwner(userId);
    const primaryPet = pets[0] ?? null;

    const latestSession = await this.sessionRepository.findOne({
      where: { userId, status: "ACTIVE" },
      order: { updatedAt: "DESC" },
    });

    return {
      primaryPet: primaryPet ? this.toPetSummary(primaryPet) : null,
      activeSessionId: latestSession?.sessionId ?? null,
      actions: [
        { id: "health", intent: "HEALTH", title: "健康咨询" },
        { id: "shop", intent: "SHOP", title: "智能选品" },
        { id: "appointment", intent: "APPOINTMENT", title: "预约医生或疫苗" },
        { id: "community", intent: "COMMUNITY", title: "附近宠友" },
      ],
      memory: primaryPet ? this.buildMemory(primaryPet) : null,
    };
  }

  async route(userId: number, dto: RouteAgentMessageDto) {
    const pets = await this.petsService.findByOwner(userId);
    const pet = dto.petId
      ? pets.find((candidate) => candidate.id === dto.petId)
      : pets[0];

    if (dto.petId && !pet) {
      throw new ForbiddenException("无权使用该宠物档案");
    }

    const message = dto.message.trim();
    const intent = this.detectIntent(message);
    const destination = this.destinationFor(intent, pet?.id);
    const session = await this.resolveSession(
      userId,
      dto.sessionId,
      pet?.id,
      message,
    );
    const userMessage = await this.messageRepository.save(
      this.messageRepository.create({
        sessionId: session.sessionId,
        userId,
        role: "USER",
        content: message,
      }),
    );
    const agentMessage = await this.messageRepository.save(
      this.messageRepository.create({
        sessionId: session.sessionId,
        userId,
        role: "AGENT",
        content: this.routeSummary(intent, pet?.name),
        intent,
        destination,
      }),
    );
    session.lastMessageAt = new Date();
    session.petId = pet?.id;
    await this.sessionRepository.save(session);

    return {
      sessionId: session.sessionId,
      userMessageId: userMessage.id,
      agentMessageId: agentMessage.id,
      intent,
      message,
      pet: pet ? this.toPetSummary(pet) : null,
      destination,
    };
  }

  async getSessions(userId: number) {
    return this.sessionRepository.find({
      where: { userId },
      order: { updatedAt: "DESC" },
      take: 50,
    });
  }

  async getMessages(userId: number, sessionId: string) {
    await this.requireSession(userId, sessionId);
    return this.messageRepository.find({
      where: { userId, sessionId },
      order: { createdAt: "ASC" },
      take: 200,
    });
  }

  private async resolveSession(
    userId: number,
    sessionId: string | undefined,
    petId: number | undefined,
    firstMessage: string,
  ) {
    if (sessionId) return this.requireSession(userId, sessionId);
    return this.sessionRepository.save(
      this.sessionRepository.create({
        sessionId: randomUUID(),
        userId,
        petId,
        title: firstMessage.slice(0, 30),
        status: "ACTIVE",
        lastMessageAt: new Date(),
      }),
    );
  }

  private async requireSession(userId: number, sessionId: string) {
    const session = await this.sessionRepository.findOne({
      where: { userId, sessionId },
    });
    if (!session) throw new ForbiddenException("无权访问该 Agent 会话");
    return session;
  }

  private routeSummary(intent: AgentIntent, petName?: string) {
    const subject = petName || "宠物";
    switch (intent) {
      case "SHOP":
        return `正在根据${subject}的档案进入智能选品。`;
      case "APPOINTMENT":
        return `正在为${subject}查找可预约的医院和医生。`;
      case "COMMUNITY":
        return "正在打开同城宠友与活动。";
      case "ORDER":
        return "正在查询你的商城订单。";
      case "HEALTH":
        return `正在结合${subject}的健康档案进入问诊。`;
    }
  }

  private detectIntent(message: string): AgentIntent {
    if (/(订单|物流|快递|退款|售后)/i.test(message)) return "ORDER";
    if (/(商城|商品|主粮|零食|购买|购物车|推荐.*粮)/i.test(message)) {
      return "SHOP";
    }
    if (/(预约|疫苗|医院|医生|挂号|接诊)/i.test(message)) {
      return "APPOINTMENT";
    }
    if (/(宠友|社区|领养|活动|同城|遛狗)/i.test(message)) {
      return "COMMUNITY";
    }
    return "HEALTH";
  }

  private destinationFor(intent: AgentIntent, petId?: number) {
    const query = petId ? { petId } : {};
    return switchIntent(intent, query);
  }

  private toPetSummary(pet: Pet) {
    return {
      id: pet.id,
      name: pet.name,
      avatar: pet.avatar,
      breed: pet.subCategory?.name ?? pet.category?.name ?? null,
      birthDate: pet.birthDate,
      weight: Number(pet.weight ?? 0),
      tags: pet.tags ?? [],
      carePlanStatus: pet.carePlanStatus,
    };
  }

  private buildMemory(pet: Pet): string {
    if (pet.tags?.length) {
      return `${pet.name}的档案标签：${pet.tags.join("、")}。后续建议会自动参考这些信息。`;
    }
    return `已连接${pet.name}的健康档案，后续建议会结合年龄、体重和健康记录。`;
  }
}

function switchIntent(intent: AgentIntent, query: { petId?: number }) {
  switch (intent) {
    case "SHOP":
      return { type: "MALL", path: "/mall", query };
    case "APPOINTMENT":
      return { type: "APPOINTMENT", path: "/health/appointments", query };
    case "COMMUNITY":
      return { type: "COMMUNITY", path: "/community", query };
    case "ORDER":
      return { type: "ORDER", path: "/mall/orders", query };
    case "HEALTH":
      return { type: "HEALTH", path: "/health/ai-diagnosis", query };
  }
}
