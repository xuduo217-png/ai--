import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { PetsModule } from "../pets/pets.module";
import { AgentController } from "./agent.controller";
import { AgentService } from "./agent.service";
import { AgentMessage } from "./entities/agent-message.entity";
import { AgentSession } from "./entities/agent-session.entity";

@Module({
  imports: [PetsModule, TypeOrmModule.forFeature([AgentSession, AgentMessage])],
  controllers: [AgentController],
  providers: [AgentService],
})
export class AgentModule {}
