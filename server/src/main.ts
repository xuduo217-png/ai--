import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { networkInterfaces } from 'node:os';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { QueryExceptionFilter } from './common/filters/query-exception.filter';
import { BusinessExceptionFilter } from './common/filters/business-exception';
import { ResponseInterceptor } from './common/interceptors/response.interceptor';

/**
 * 获取启动日志中展示的局域网访问地址
 * 优先使用环境变量覆写，避免不同机器上打印错误的固定 IP。
 */
function getLanAccessHost(): string {
  const configuredHost = process.env.SERVER_LAN_HOST?.trim();
  if (configuredHost) {
    return configuredHost;
  }

  const networks = networkInterfaces();

  // 优先选择首个非回环 IPv4 地址，避免输出不可访问的回环地址。
  for (const addresses of Object.values(networks)) {
    const ipv4Address = addresses?.find((address) => {
      return address.family === 'IPv4' && !address.internal;
    });

    if (ipv4Address?.address) {
      return ipv4Address.address;
    }
  }

  // 未识别到有效网卡时回退为 localhost，保证日志输出仍然安全可用。
  return 'localhost';
}

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    rawBody: true,
    // 启用定时任务的 CORS 配置
    logger: ['error', 'warn', 'log', 'debug', 'verbose'],
  });
  const swaggerPath = 'api-docs';
  const swaggerEnabled = process.env.ENABLE_SWAGGER === 'true';

  // 恢复全局参数转换，保证 Query/Param/Body 的 DTO 校验和类型推断一致生效。
  app.useGlobalPipes(
    new ValidationPipe({
      transform: true,
      whitelist: true,
      transformOptions: {
        enableImplicitConversion: true,
      },
    }),
  );

  // 按“数据库错误 -> 业务错误 -> 通用 HTTP 错误”的顺序恢复全局异常过滤器，
  // 避免通用 HttpException 处理提前吞掉更具体的异常语义。
  app.useGlobalFilters(
    new QueryExceptionFilter(),
    new BusinessExceptionFilter(),
    new HttpExceptionFilter(),
  );

  // 全局响应拦截器
  app.useGlobalInterceptors(new ResponseInterceptor());

  // 启用 CORS
  app.enableCors({
    origin: true,
    credentials: true,
  });

  // Swagger 默认保持关闭，仅在显式开启时注册文档路由，确保日志与实际状态一致。
  if (swaggerEnabled) {
    const config = new DocumentBuilder()
      .setTitle('Pet Hospitals API')
      .setDescription('宠物医院管理系统 API')
      .setVersion('1.0')
      .addTag('auth', '认证相关接口')
      .addTag('users', '用户管理接口')
      .addTag('pets', '宠物管理接口')
      .addTag('departments', '科室管理接口')
      .addTag('doctors', '医生管理接口')
      .addTag('schedules', '排班管理接口')
      .addTag('appointments', '预约管理接口')
      .addTag('chat', '聊天接口')
      .addTag('shop', '商城接口')
      .addTag('ai-consultation', 'AI 问诊接口')
      .addTag('upload', '文件上传接口')
      .addBearerAuth()
      .build();

    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup(swaggerPath, app, document);
  }

  const port = process.env.PORT ?? 3000;
  const lanAccessHost = getLanAccessHost();
  // 监听所有网络接口（0.0.0.0），以便局域网内其他设备可以访问
  await app.listen(port, '0.0.0.0');

  console.log(`\n✅ 应用启动成功！`);
  console.log(`🚀 Application is running on: http://localhost:${port}`);
  if (swaggerEnabled) {
    console.log(
      `📚 Swagger documentation: http://localhost:${port}/${swaggerPath}`,
    );
  } else {
    console.log(`📚 Swagger documentation: disabled`);
  }
  console.log(`🌐 局域网访问地址: http://${lanAccessHost}:${port}`);
  console.log(`🔧 环境模式: ${process.env.NODE_ENV || 'development'}`);
  console.log(`\n💡 队列系统说明:`);
  console.log(`   - 西医诊断队列: western-diagnosis`);
  console.log(`   - 中医诊断队列: tcm-diagnosis`);
  console.log(`   - 日志目录: logs/ai-diagnosis/`);
  console.log(`\n`);
}
bootstrap();
