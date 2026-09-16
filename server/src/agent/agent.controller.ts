import { Body, Controller, Get, Param, Post, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";
import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";
import { Roles } from "../auth/decorators/roles.decorator";
import { RolesGuard } from "../auth/guards/roles.guard";
import { CurrentUser } from "../common/decorators/current-user.decorator";
import { AgentService } from "./agent.service";
import { RouteAgentMessageDto } from "./dto/route-agent-message.dto";

@ApiTags("agent")
@ApiBearerAuth()
@Controller("agent")
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles("USER")
export class AgentController {
  constructor(private readonly agentService: AgentService) {}

  @Get("home")
  @ApiOperation({ summary: "获取当前用户的 Agent 首页上下文" })
  getHome(@CurrentUser("id") userId: number) {
    return this.agentService.getHome(userId);
  }

  @Get("sessions")
  @ApiOperation({ summary: "获取当前用户的 Agent 会话列表" })
  getSessions(@CurrentUser("id") userId: number) {
    return this.agentService.getSessions(userId);
  }

  @Get("sessions/:sessionId/messages")
  @ApiOperation({ summary: "获取当前用户指定 Agent 会话的消息" })
  getMessages(
    @CurrentUser("id") userId: number,
    @Param("sessionId") sessionId: string,
  ) {
    return this.agentService.getMessages(userId, sessionId);
  }

  @Post("route")
  @ApiOperation({ summary: "识别 Agent 请求并返回业务目标" })
  route(@CurrentUser("id") userId: number, @Body() dto: RouteAgentMessageDto) {
    return this.agentService.route(userId, dto);
  }
}
