import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Post,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiParam, ApiTags } from "@nestjs/swagger";
import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";
import { CurrentUser } from "../common/decorators/current-user.decorator";
import { BlockUserDto } from "./dto/block-user.dto";
import { CreateReportDto } from "./dto/create-report.dto";
import { ModerationService } from "./moderation.service";

@ApiTags("UGC 举报与屏蔽")
@ApiBearerAuth()
@Controller("moderation")
@UseGuards(JwtAuthGuard)
export class ModerationController {
  constructor(private readonly moderationService: ModerationService) {}

  @Post("reports")
  @ApiOperation({ summary: "提交 UGC 举报" })
  async createReport(@CurrentUser() user: any, @Body() dto: CreateReportDto) {
    const report = await this.moderationService.createReport(user.id, dto);
    return {
      success: true,
      data: report,
    };
  }

  @Post("blocks")
  @ApiOperation({ summary: "屏蔽用户" })
  async blockUser(@CurrentUser() user: any, @Body() dto: BlockUserDto) {
    const block = await this.moderationService.blockUser(user.id, dto);
    return {
      success: true,
      data: block,
    };
  }

  @Delete("blocks/:blockedUserId")
  @ApiOperation({ summary: "取消屏蔽用户" })
  @ApiParam({ name: "blockedUserId", description: "被屏蔽用户ID" })
  async unblockUser(
    @CurrentUser() user: any,
    @Param("blockedUserId", ParseIntPipe) blockedUserId: number,
  ) {
    await this.moderationService.unblockUser(user.id, blockedUserId);
    return {
      success: true,
    };
  }

  @Get("blocks")
  @ApiOperation({ summary: "获取我的屏蔽列表" })
  async getBlocks(@CurrentUser() user: any) {
    return {
      success: true,
      data: await this.moderationService.getBlocks(user.id),
    };
  }
}
