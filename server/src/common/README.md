# 统一响应和错误处理使用指南

## 概述

本项目现在使用统一的响应格式和错误处理机制，确保所有 API 返回一致的数据结构。

## 统一响应格式

### 普通响应

```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "id": 1,
    "name": "张三"
  },
  "meta": {
    "timestamp": "2024-01-17T10:30:00.000Z"
  }
}
```

### 分页响应

```json
{
  "success": true,
  "statusCode": 200,
  "data": [
    { "id": 1, "name": "张三" },
    { "id": 2, "name": "李四" }
  ],
  "pagination": {
    "total": 100,
    "page": 1,
    "limit": 10,
    "totalPages": 10
  },
  "meta": {
    "timestamp": "2024-01-17T10:30:00.000Z"
  }
}
```

## 统一错误响应格式

### HTTP 错误

```json
{
  "statusCode": 404,
  "message": "用户不存在",
  "error": "Not Found",
  "timestamp": "2024-01-17T10:30:00.000Z",
  "path": "/api/users/999",
  "method": "GET"
}
```

### 业务错误

```json
{
  "statusCode": 400,
  "message": "预约时间冲突",
  "code": "3001",
  "error": "BUSINESS_ERROR",
  "timestamp": "2024-01-17T10:30:00.000Z",
  "path": "/api/appointments",
  "method": "POST"
}
```

### 数据库错误

```json
{
  "statusCode": 409,
  "message": "数据已存在，请勿重复提交",
  "error": "DUPLICATE_ENTRY",
  "timestamp": "2024-01-17T10:30:00.000Z",
  "path": "/api/users",
  "method": "POST"
}
```

## 使用方法

### 1. 在 Service 中使用业务异常

```typescript
import { ErrorCode, createBusinessException } from '../common/constants/error-codes';

@Injectable()
export class UsersService {
  async findById(id: number) {
    const user = await this.userRepository.findOne({ where: { id } });

    if (!user) {
      // 使用错误码体系
      throw createBusinessException(ErrorCode.USER_NOT_FOUND);
    }

    return user;
  }

  async updateAppointment(appointmentId: number, data: UpdateAppointmentDto) {
    // 检查预约时间是否冲突
    const hasConflict = await this.checkTimeConflict(data.date, data.timeSlot);

    if (hasConflict) {
      // 使用自定义消息
      throw createBusinessException(
        ErrorCode.APPOINTMENT_CONFLICT,
        '该时间段已有预约，请选择其他时间',
      );
    }

    // 更新预约...
  }
}
```

### 2. 在 Controller 中返回标准格式

响应拦截器会自动包装返回数据，无需手动处理：

```typescript
@Controller('users')
export class UsersController {
  @Get(':id')
  async findOne(@Param('id') id: string) {
    // 直接返回数据，拦截器会自动包装
    return this.usersService.findById(+id);
  }

  @Get()
  async findAll(@Query() query: PaginationDto) {
    // 返回分页数据，拦截器会自动添加 pagination 字段
    return this.usersService.findAll(query);
  }
}
```

### 3. 抛出标准 HTTP 异常

```typescript
import { BadRequestException, NotFoundException, ForbiddenException } from '@nestjs/common';

@Injectable()
export class AppointmentsService {
  async cancelAppointment(id: number, userId: number) {
    const appointment = await this.findOne(id);

    if (!appointment) {
      throw new NotFoundException('预约不存在');
    }

    if (appointment.userId !== userId) {
      throw new ForbiddenException('无权取消此预约');
    }

    if (appointment.status === 'COMPLETED') {
      throw new BadRequestException('已完成的预约无法取消');
    }

    // 取消预约...
  }
}
```

## 错误码参考

### 认证相关 (1xxx)

| 错误码 | 消息 | HTTP状态码 |
|--------|------|-----------|
| 1001 | 未授权访问 | 401 |
| 1002 | 登录已过期，请重新登录 | 401 |
| 1003 | 用户名或密码错误 | 401 |
| 1007 | 权限不足 | 403 |

### 资源相关 (2xxx)

| 错误码 | 消息 | HTTP状态码 |
|--------|------|-----------|
| 2001 | 用户不存在 | 404 |
| 2002 | 宠物不存在 | 404 |
| 2003 | 预约不存在 | 404 |
| 2004 | 医生不存在 | 404 |

### 业务逻辑 (3xxx)

| 错误码 | 消息 | HTTP状态码 |
|--------|------|-----------|
| 3001 | 预约时间冲突 | 400 |
| 3002 | 余额不足 | 400 |
| 3003 | 已超过免费消息次数 | 400 |
| 3005 | 预约时间无效 | 400 |

### 文件相关 (4xxx)

| 错误码 | 消息 | HTTP状态码 |
|--------|------|-----------|
| 4001 | 文件不存在 | 404 |
| 4002 | 文件大小超过限制 | 400 |
| 4003 | 不支持的文件类型 | 400 |

### 系统错误 (5xxx)

| 错误码 | 消息 | HTTP状态码 |
|--------|------|-----------|
| 5001 | 数据库操作失败 | 500 |
| 5002 | 短信发送失败 | 500 |
| 5003 | AI服务异常 | 500 |

## 注意事项

1. **自动包装**: 所有响应都会被拦截器自动包装，不需要手动构造响应对象
2. **错误码优先**: 优先使用预定义的错误码，保持错误处理的一致性
3. **自定义消息**: 如果需要特定的错误消息，可以在 `createBusinessException` 第二个参数传入
4. **验证错误**: DTO 验证失败会自动返回详细的错误信息数组
5. **数据库错误**: 常见的数据库错误（如唯一键冲突）会被自动转换为友好的错误消息

## 测试示例

### 测试成功响应

```bash
curl http://localhost:3000/users/1
```

响应：
```json
{
  "success": true,
  "statusCode": 200,
  "data": { "id": 1, "username": "test" },
  "meta": { "timestamp": "2024-01-17T10:30:00.000Z" }
}
```

### 测试 404 错误

```bash
curl http://localhost:3000/users/999
```

响应：
```json
{
  "statusCode": 404,
  "message": "用户不存在",
  "code": "2001",
  "error": "BUSINESS_ERROR",
  "timestamp": "2024-01-17T10:30:00.000Z",
  "path": "/users/999",
  "method": "GET"
}
```

### 测试验证错误

```bash
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"a","password":"123"}'
```

响应：
```json
{
  "statusCode": 400,
  "message": "验证失败",
  "error": ["用户名长度不能少于3个字符", "密码长度不能少于6位"],
  "timestamp": "2024-01-17T10:30:00.000Z",
  "path": "/auth/register",
  "method": "POST"
}
```
