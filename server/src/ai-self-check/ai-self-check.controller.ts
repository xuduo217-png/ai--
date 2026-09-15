import {
  Controller,
  Get,
  Post,
  Put,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  ParseIntPipe,
} from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiParam } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/entities/user.entity';
import { AiSelfCheckService } from './ai-self-check.service';
import {
  CreateListDto,
  UpdateListDto,
  QueryListDto,
  CreateQuestionDto,
  UpdateQuestionDto,
  ReorderListsDto,
  ReorderQuestionsDto,
  ReorderOptionsDto,
} from './dto';

/**
 * AI 自查表控制器
 */
@Controller('ai-self-check')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AiSelfCheckController {
  constructor(private readonly selfCheckService: AiSelfCheckService) {}

  /**
   * 获取自查表列表
   */
  @Get('lists')
  getLists(@Query() query: QueryListDto) {
    return this.selfCheckService.getLists(query);
  }

  /**
   * 获取自查表详情
   */
  @Get('lists/:id')
  getListDetail(@Param('id') id: string) {
    return this.selfCheckService.getListDetail(+id);
  }

  /**
   * 创建自查表（管理员）
   */
  @Post('lists')
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN)
  createList(@Body() dto: CreateListDto) {
    return this.selfCheckService.createList(dto);
  }

  /**
   * 更新自查表（管理员）
   */
  @Put('lists/:id')
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN)
  updateList(@Param('id') id: string, @Body() dto: UpdateListDto) {
    return this.selfCheckService.updateList(+id, dto);
  }

  /**
   * 更新状态（管理员）
   */
  @Post('lists/:id/status')
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN)
  updateStatus(
    @Param('id') id: string,
    @Body('status') status: 'ACTIVE' | 'INACTIVE',
  ) {
    return this.selfCheckService.updateStatus(+id, status);
  }

  /**
   * 删除自查表（管理员）
   */
  @Delete('lists/:id')
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN)
  deleteList(@Param('id') id: string) {
    return this.selfCheckService.deleteList(+id);
  }

  /**
   * 获取问题列表
   */
  @Get('questions')
  getQuestions(@Query('listId') listId: string) {
    return this.selfCheckService.getQuestions(+listId);
  }

  /**
   * 创建问题（管理员）
   */
  @Post('questions')
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN)
  createQuestion(@Body() dto: CreateQuestionDto) {
    return this.selfCheckService.createQuestion(dto);
  }

  /**
   * 更新问题（管理员）
   */
  @Put('questions/:id')
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN)
  updateQuestion(@Param('id') id: string, @Body() dto: UpdateQuestionDto) {
    return this.selfCheckService.updateQuestion(+id, dto);
  }

  /**
   * 删除问题（管理员）
   */
  @Delete('questions/:id')
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN)
  deleteQuestion(@Param('id') id: string) {
    return this.selfCheckService.deleteQuestion(+id);
  }

  /**
   * 根据宠物ID获取自查表列表
   * 返回公共项 + 匹配的特定项
   */
  @Get('lists/by-pet/:petId')
  getListsByPetId(@Param('petId') petId: string) {
    return this.selfCheckService.getListsByPetId(+petId);
  }

  /**
   * 批量更新自查表排序
   * @param dto 排序 DTO
   * @returns 操作结果
   */
  @Patch('lists/reorder')
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @ApiOperation({ summary: '批量更新自查表排序' })
  @ApiResponse({ status: 200, description: '排序更新成功' })
  @ApiResponse({ status: 400, description: '参数错误' })
  @ApiResponse({ status: 401, description: '未授权' })
  @ApiResponse({ status: 403, description: '权限不足' })
  async reorderLists(@Body() dto: ReorderListsDto) {
    return this.selfCheckService.reorderLists(dto.listIds);
  }

  /**
   * 批量更新问题排序
   * @param dto 排序 DTO
   * @returns 操作结果
   */
  @Patch('questions/reorder')
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @ApiOperation({ summary: '批量更新问题排序' })
  @ApiResponse({ status: 200, description: '排序更新成功' })
  @ApiResponse({ status: 400, description: '参数错误' })
  @ApiResponse({ status: 401, description: '未授权' })
  @ApiResponse({ status: 403, description: '权限不足' })
  async reorderQuestions(@Body() dto: ReorderQuestionsDto) {
    return this.selfCheckService.reorderQuestions(dto.questionIds);
  }

  /**
   * 批量更新选项排序
   * @param questionId 问题 ID
   * @param dto 排序 DTO
   * @returns 操作结果
   */
  @Patch('questions/:questionId/options/reorder')
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @ApiOperation({ summary: '批量更新选项排序' })
  @ApiParam({ name: 'questionId', description: '问题 ID', type: Number })
  @ApiResponse({ status: 200, description: '排序更新成功' })
  @ApiResponse({ status: 400, description: '参数错误' })
  @ApiResponse({ status: 401, description: '未授权' })
  @ApiResponse({ status: 403, description: '权限不足' })
  @ApiResponse({ status: 404, description: '问题不存在' })
  async reorderOptions(
    @Param('questionId', ParseIntPipe) questionId: number,
    @Body() dto: ReorderOptionsDto,
  ) {
    return this.selfCheckService.reorderOptions(questionId, dto.optionIds);
  }
}
