import {
  Controller,
  Post,
  Get,
  Delete,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
  UseGuards,
  Query,
  Param,
  Req,
  ParseIntPipe,
  createParamDecorator,
  ExecutionContext,
} from '@nestjs/common';
import {
  FileFieldsInterceptor,
  FileInterceptor,
  FilesInterceptor,
} from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { UploadService } from './upload.service';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiConsumes,
  ApiBody,
  ApiQuery,
} from '@nestjs/swagger';
import { Express, Request } from 'express';
import { ConfigService } from '@nestjs/config';
import { UploadFileDto } from './dto/upload-file.dto';
import { QueryFilesDto } from './dto/query-files.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

// 创建 UploadedFiles 装饰器
const UploadedFiles = createParamDecorator(
  (data: unknown, ctx: ExecutionContext) => {
    const req = ctx.switchToHttp().getRequest();
    return req.files;
  },
);

// 默认配置，用于装饰器
const defaultMulterOptions = UploadService.getMulterOptionsStatic({
  get: (key: string) => {
    if (key === 'UPLOAD_DEST') return './uploads';
    if (key === 'MAX_FILE_SIZE') return 838860800; // 800MB (支持大视频上传)
    return undefined;
  },
} as ConfigService);

@ApiTags('upload')
@ApiBearerAuth()
@Controller('upload')
@UseGuards(JwtAuthGuard)
export class UploadController {
  constructor(private readonly uploadService: UploadService) {}

  private parseBoolean(value: unknown): boolean | undefined {
    if (typeof value === 'boolean') return value;
    if (typeof value === 'string') {
      const normalized = value.trim().toLowerCase();
      if (normalized === 'true' || normalized === '1') return true;
      if (normalized === 'false' || normalized === '0') return false;
    }
    return undefined;
  }

  private mergeUploadMetadata(
    queryMetadata: UploadFileDto,
    bodyMetadata?: Record<string, unknown>,
  ): UploadFileDto {
    const mergedMetadata = {
      ...(bodyMetadata || {}),
      ...(queryMetadata || {}),
    } as Record<string, unknown>;

    return {
      category: mergedMetadata.category as string | undefined,
      description: mergedMetadata.description as string | undefined,
      tags: mergedMetadata.tags as string | undefined,
      compress: this.parseBoolean(mergedMetadata.compress),
      generateThumbnail: this.parseBoolean(mergedMetadata.generateThumbnail),
    };
  }

  @Post('image')
  @UseInterceptors(FileInterceptor('file', defaultMulterOptions))
  @ApiOperation({ summary: '上传图片' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: {
          type: 'string',
          format: 'binary',
        },
        category: {
          type: 'string',
          description: '文件分类',
        },
        description: {
          type: 'string',
          description: '文件描述',
        },
        tags: {
          type: 'string',
          description: '文件标签',
        },
        compress: {
          type: 'boolean',
          description: '是否自动压缩',
          default: true,
        },
        generateThumbnail: {
          type: 'boolean',
          description: '是否生成缩略图',
          default: true,
        },
      },
    },
  })
  async uploadImage(
    @UploadedFile() file: Express.Multer.File,
    @CurrentUser() user: User,
    @Query() queryMetadata: UploadFileDto,
    @Req() req: Request,
  ) {
    if (!file) {
      throw new BadRequestException('文件上传失败');
    }
    const metadata = this.mergeUploadMetadata(
      queryMetadata,
      req.body as Record<string, unknown>,
    );

    // 保存文件记录到数据库
    const fileRecord = await this.uploadService.saveFileRecord(
      file,
      user.id,
      metadata,
      undefined,
      ['image'],
    );

    // 构建响应数据
    const response: any = {
      url: fileRecord.path,
      filename: file.filename,
      originalName: file.originalname,
      size: fileRecord.size,
      id: fileRecord.id,
    };

    // 如果是图片且处理成功，添加额外信息
    if (fileRecord.width && fileRecord.height) {
      response.width = fileRecord.width;
      response.height = fileRecord.height;
    }

    if (fileRecord.thumbnailPath) {
      response.thumbnail = fileRecord.thumbnailPath;
    }

    return response;
  }

  @Post('images/batch')
  @UseInterceptors(FilesInterceptor('files', 9, defaultMulterOptions))
  @ApiOperation({ summary: '批量上传图片（最多9张）' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        files: {
          type: 'array',
          items: {
            type: 'string',
            format: 'binary',
          },
          maxItems: 9,
        },
        category: {
          type: 'string',
          description: '文件分类',
        },
        compress: {
          type: 'boolean',
          description: '是否自动压缩',
          default: true,
        },
        generateThumbnail: {
          type: 'boolean',
          description: '是否生成缩略图',
          default: true,
        },
      },
    },
  })
  async uploadImagesBatch(
    @UploadedFiles() files: Express.Multer.File[],
    @CurrentUser() user: User,
    @Query() queryMetadata: UploadFileDto,
    @Req() req: Request,
  ) {
    if (!files || files.length === 0) {
      throw new BadRequestException('没有上传文件');
    }

    if (files.length > 9) {
      throw new BadRequestException('最多只能上传 9 张图片');
    }

    const metadata = this.mergeUploadMetadata(
      queryMetadata,
      req.body as Record<string, unknown>,
    );

    // 批量处理文件
    const results = await this.uploadService.processBatchUpload(
      files,
      user.id,
      metadata,
    );

    return {
      total: files.length,
      successCount: results.filter((r) => r.success).length,
      failCount: results.filter((r) => !r.success).length,
      results,
    };
  }

  @Post('file')
  @UseInterceptors(
    FileFieldsInterceptor(
      [
        { name: 'file', maxCount: 1 },
        { name: 'thumbnail', maxCount: 1 },
      ],
      defaultMulterOptions,
    ),
  )
  @ApiOperation({ summary: '上传文件' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: {
          type: 'string',
          format: 'binary',
        },
        thumbnail: {
          type: 'string',
          format: 'binary',
          description:
            '可选的视频缩略图文件，推荐由 APP 端本地抽帧后随视频一起上传',
        },
        category: {
          type: 'string',
          description: '文件分类',
        },
        description: {
          type: 'string',
          description: '文件描述',
        },
        tags: {
          type: 'string',
          description: '文件标签',
        },
        compress: {
          type: 'boolean',
          description: '是否自动压缩视频（后台异步处理）',
          default: true,
        },
      },
    },
  })
  async uploadFile(
    @UploadedFiles()
    files: {
      file?: Express.Multer.File[];
      thumbnail?: Express.Multer.File[];
    },
    @CurrentUser() user: User,
    @Query() queryMetadata: UploadFileDto,
    @Req() req: Request,
  ) {
    const file = files?.file?.[0];
    const thumbnail = files?.thumbnail?.[0];

    if (!file) {
      throw new BadRequestException('文件上传失败');
    }
    const metadata = this.mergeUploadMetadata(
      queryMetadata,
      req.body as Record<string, unknown>,
    );

    // 保存文件记录到数据库
    const fileRecord = await this.uploadService.saveFileRecord(
      file,
      user.id,
      metadata,
      thumbnail,
      ['video', 'audio', 'pdf'],
    );

    return {
      url: fileRecord.path,
      filename: file.filename,
      originalName: file.originalname,
      size: fileRecord.size,
      thumbnail: fileRecord.thumbnailPath,
      id: fileRecord.id,
    };
  }

  @Get()
  @ApiOperation({ summary: '获取文件列表' })
  @ApiQuery({ name: 'page', required: false, example: 1 })
  @ApiQuery({ name: 'limit', required: false, example: 10 })
  @ApiQuery({ name: 'category', required: false })
  @ApiQuery({
    name: 'fileType',
    required: false,
    enum: ['image', 'pdf', 'document'],
  })
  async getFiles(@Query() query: QueryFilesDto, @CurrentUser() user: User) {
    return this.uploadService.getFileRecords(query, user.id);
  }

  @Get(':id')
  @ApiOperation({ summary: '获取文件详情' })
  async getFile(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: User,
  ) {
    return this.uploadService.getFileRecord(id, user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除文件' })
  async deleteFile(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: User,
  ) {
    await this.uploadService.deleteFile(id, user.id);
    return { message: '文件删除成功' };
  }

  @Get('stats/summary')
  @ApiOperation({ summary: '获取文件统计' })
  async getFileStats(@CurrentUser() user: User) {
    return this.uploadService.getFileStats(user.id);
  }
}
