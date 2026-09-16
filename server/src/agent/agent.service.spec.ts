import { ForbiddenException } from "@nestjs/common";
import { AgentService } from "./agent.service";
import { PetsService } from "../pets/pets.service";
import { Pet } from "../pets/entities/pet.entity";
import { Repository } from "typeorm";
import { AgentSession } from "./entities/agent-session.entity";
import { AgentMessage } from "./entities/agent-message.entity";

describe("AgentService", () => {
  const pet = {
    id: 12,
    name: "团团",
    avatar: "/uploads/tuan.png",
    weight: 5.8,
    tags: ["肠胃敏感"],
    carePlanStatus: "COMPLETED",
    category: { name: "犬" },
    subCategory: { name: "柯基" },
  } as Pet;

  let service: AgentService;
  let petsService: Pick<PetsService, "findByOwner">;
  let sessionRepository: jest.Mocked<Repository<AgentSession>>;
  let messageRepository: jest.Mocked<Repository<AgentMessage>>;

  beforeEach(() => {
    petsService = { findByOwner: jest.fn().mockResolvedValue([pet]) };
    sessionRepository = {
      findOne: jest.fn().mockResolvedValue(null),
      find: jest.fn().mockResolvedValue([]),
      create: jest.fn((value) => value as AgentSession),
      save: jest.fn(async (value) => value as AgentSession),
    } as unknown as jest.Mocked<Repository<AgentSession>>;
    let messageId = 0;
    messageRepository = {
      find: jest.fn().mockResolvedValue([]),
      create: jest.fn((value) => value as AgentMessage),
      save: jest.fn(
        async (value) => ({ ...value, id: ++messageId }) as AgentMessage,
      ),
    } as unknown as jest.Mocked<Repository<AgentMessage>>;
    service = new AgentService(
      petsService as PetsService,
      sessionRepository as Repository<AgentSession>,
      messageRepository as Repository<AgentMessage>,
    );
  });

  it("builds the home context from the authenticated user pet", async () => {
    const result = await service.getHome(7);

    expect(petsService.findByOwner).toHaveBeenCalledWith(7);
    expect(result.primaryPet).toMatchObject({
      id: 12,
      name: "团团",
      breed: "柯基",
    });
    expect(result.memory).toContain("肠胃敏感");
  });

  it.each([
    ["查一下订单物流", "ORDER", "ORDER"],
    ["推荐一款主粮", "SHOP", "MALL"],
    ["预约周末疫苗", "APPOINTMENT", "APPOINTMENT"],
    ["看看附近宠友活动", "COMMUNITY", "COMMUNITY"],
    ["今天有点软便", "HEALTH", "HEALTH"],
  ])("routes %s to %s", async (message, intent, destinationType) => {
    const result = await service.route(7, { message });

    expect(result.intent).toBe(intent);
    expect(result.destination.type).toBe(destinationType);
    expect(result.destination.query).toEqual({ petId: 12 });
    expect(result.sessionId).toEqual(expect.any(String));
    expect(messageRepository.save).toHaveBeenCalledTimes(2);
  });

  it("rejects a pet that does not belong to the current user", async () => {
    await expect(
      service.route(7, { message: "预约医生", petId: 99 }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});
