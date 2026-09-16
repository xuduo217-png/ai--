# Pet Hospitals API 接口文档

> 后端 NestJS 服务器的完整 API 接口文档基础 URL: `http://localhost:3000`（本机联调示例；跨设备访问时请替换为当前可达的局域网 IP、域名或代理地址）

**说明**：

- ✅ 表示需要 JWT 认证
- 🎭 表示需要特定角色权限
- 🌐 表示公开接口（无需认证）

**Admin 联调约定**：

- `admin` 端发起后端请求时，推荐继续使用相对路径 `VITE_SERVER_API_BASE_URL=/server-api`，由 Vite 开发代理转发到真实后端；如需切换开发代理目标，可配置 `VITE_SERVER_API_PROXY_TARGET`。
- 图片、富文本和上传返回值统一保留相对路径 `/uploads/...`，对象实际存储在腾讯云 COS 的 `uploads/` 前缀下。`admin` 端通过 `VITE_STATIC_BASE_PATH=https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com` 补全完整地址；Flutter 端通过 `ASSET_BASE_URL` 补全，默认使用同一 COS 域名。
- 旧 `@/api/*` axios 封装仍会读取 `VITE_API_BASE_PATH`；若还需要兼容旧 `/api` 入口，可通过 `VITE_API_PROXY_TARGET` 覆盖 Vite 代理目标。
- `http://localhost:3000`、`ws://localhost:3000` 仅表示本机联调示例，不应作为跨设备、测试环境或线上环境的固定配置。

---

## Agent 聚合接口

以下接口用于正式 Flutter Agent 首页，均要求用户 JWT，且只允许访问当前用户自己的宠物档案。

### 获取 Agent 首页上下文

- `GET /agent/home`
- 角色：`USER`
- 返回：`primaryPet`、固定业务入口 `actions`、基于真实宠物档案生成的 `memory`。
- 用户没有宠物时 `primaryPet` 和 `memory` 为 `null`，客户端应引导建立宠物档案。

### 识别请求并返回业务目标

- `POST /agent/route`
- 角色：`USER`
- 请求体：`{ "message": "帮团团预约周末疫苗", "petId": 12 }`
- `petId` 可选；传入时服务端会校验宠物归属。
- 返回意图：`HEALTH`、`SHOP`、`APPOINTMENT`、`COMMUNITY`、`ORDER`。
- 返回 `destination` 供客户端进入现有正式业务页面，客户端不得自行用关键词决定目标模块。
- 返回 `sessionId`、用户消息 ID 和 Agent 消息 ID；消息已经写入独立 Agent 会话表。

### Agent 会话记录

- `GET /agent/sessions`：获取当前用户最近 50 个会话。
- `GET /agent/sessions/:sessionId/messages`：获取指定会话最多 200 条消息。
- 服务端按 JWT 用户校验会话归属，不能读取其他用户的会话。

---

## 目录

1. [Auth 模块](#auth-模块) - 认证与授权
2. [Users 模块](#users-模块) - 用户管理
3. [Pets 模块](#pets-模块) - 宠物管理
4. [Pet Categories 模块](#pet-categories-模块) - 宠物类别管理
5. [Hospitals 模块](#hospitals-模块) - 医院管理
6. [Departments 模块](#departments-模块) - 科室管理
7. [Doctors 模块](#doctors-模块) - 医生管理
8. [Schedules 模块](#schedules-模块) - 排班管理
9. [Appointments 模块](#appointments-模块) - 预约管理
10. [AI Consultation 模块](#ai-consultation-模块) - AI 问诊
11. [AI Self Check 模块](#ai-self-check-模块) - AI 自查表管理
12. [Chat 模块](#chat-模块) - 聊天系统
13. [Shop 模块](#shop-模块) - 商城管理
14. [Upload 模块](#upload-模块) - 文件上传
15. [Audit 模块](#audit-模块) - 审计日志
16. [SMS 模块](#sms-模块) - 短信服务
17. [Payment 模块](#payment-模块) - 支付管理
18. [Health Articles 模块](#health-articles-模块) - 健康知识
19. [Health Appointments 模块](#health-appointments-模块) - 健康预约
20. [System Configs 模块](#system-configs-模块) - 系统配置
21. [AI Diagnosis Report 模块](#ai-diagnosis-report-模块) - AI 诊断报告
22. [Statistics 模块](#statistics-模块) - 统计数据
23. [Friends 模块](#friends-模块) - 好友关系管理
24. [Marketplace Chat 模块](#marketplace-chat-模块) - 二手商城买卖聊天
25. [Notifications 模块](#notifications-模块) - 站内通知
26. [Charity 模块](#charity-模块) - 公益管理
27. [Activities 模块](#activities-模块) - 活动管理
28. [Lost Found 模块](#lost-found-模块) - 走失招领
29. [Wallet 模块](#wallet-模块) - 钱包管理
30. [Community 模块](#community-模块) - 社区内容与关注关系
31. [Moderation 模块](#moderation-模块) - UGC 举报与屏蔽治理

---

## Auth 模块

认证与授权相关接口

| HTTP 方法 | 路径                     | 描述                | 权限 |
| --------- | ------------------------ | ------------------- | ---- |
| POST      | /auth/login              | 用户名密码登录      | 🌐   |
| POST      | /auth/register           | 用户注册            | 🌐   |
| POST      | /auth/send-code          | 发送短信验证码      | 🌐   |
| POST      | /auth/verify-code        | 校验短信验证码      | 🌐   |
| POST      | /auth/register/phone     | 手机号注册          | 🌐   |
| POST      | /auth/login/phone        | 手机号+密码登录     | 🌐   |
| POST      | /auth/login/doctor/phone | 医生手机号+密码登录 | 🌐   |
| POST      | /auth/login/sms          | 短信验证码登录      | 🌐   |
| POST      | /auth/reset-password     | 重置密码            | 🌐   |
| GET       | /auth/profile            | 获取当前用户信息    | ✅   |

> 认证模块当前约定：成功响应走统一成功包裹（`code=0`）；业务失败与鉴权失败也返回 HTTP `200`，前端应根据响应体中的 `success=false`、`code`、`statusCode`、`message` 判定失败，而不是只看 HTTP 状态码。

### 请求示例

```typescript
// 登录
POST /auth/login
{
  "username": "string",
  "password": "string"
}

// 发送验证码
POST /auth/send-code
{
  "phone": "13800138000",
  "type": "reset_password",
  "accountType": "user"
}

// 校验验证码（不消费）
POST /auth/verify-code
{
  "phone": "13800138000",
  "code": "123456",
  "type": "reset_password",
  "accountType": "user"
}

// 手机号+密码登录
POST /auth/login/phone
{
  "phone": "13800138000",
  "password": "password123"
}

// 医生手机号+密码登录
POST /auth/login/doctor/phone
{
  "phone": "13800138000",
  "password": "password123"
}

// 短信验证码登录
POST /auth/login/sms
{
  "phone": "13800138000",
  "code": "123456"
}

// 重置密码
POST /auth/reset-password
{
  "phone": "13800138000",
  "code": "123456",
  "newPassword": "newPassword123",
  "accountType": "user"
}
```

> 说明：`/auth/send-code` 的 `type` 可选值为 `register`、`login`、`reset_password`。当 `type=register` 且手机号已在系统注册时，接口返回业务失败，`message` 为 `手机号已被注册`，不会继续发送短信验证码。当 `type=reset_password` 时，可传 `accountType=user|doctor` 校验要找回的是普通用户账号还是医生账号；不传默认 `user`。目标普通用户或医生手机号不存在时返回业务失败，且不会发送短信验证码。
>
> 说明：`/auth/verify-code` 在 `type=reset_password` 时同样支持 `accountType=user|doctor`，用于校验该手机号是否属于对应账号类型；目标账号不存在时验证码校验不通过。
>
> 说明：`/auth/reset-password` 的 `accountType` 可选值为 `user`、`doctor`，不传默认 `user`。普通用户和医生账号使用同一手机号验证码类型 `reset_password`，提交时按 `accountType` 重置对应账号密码。

### 医生手机号登录

**端点:** `POST /auth/login/doctor/phone`

**描述:** 医生通过手机号和密码登录系统

**请求体:**

```json
{
  "phone": "13800138000",
  "password": "password123"
}
```

**成功响应 (200):**

```json
{
  "code": 0,
  "message": "Success",
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "doctor": {
      "id": 1,
      "phone": "13800138000",
      "username": "doctor001",
      "name": "张医生",
      "specialty": "内科",
      "hospitalId": 1,
      "departmentId": 1,
      "avatar": null
    }
  }
}
```

**错误响应（HTTP 200，按响应体 `success=false/statusCode` 判定失败）:**

- 登录失败、鉴权失败、参数校验失败等业务失败统一返回 `HTTP 200`
- 前端应优先读取 `message` 进行提示，并结合 `code/statusCode` 做鉴权兜底处理

- `statusCode=401` - 手机号或密码错误
- `statusCode=403` - 医生账号已被禁用

```json
{
  "success": false,
  "code": 401,
  "statusCode": 401,
  "message": "手机号或密码错误",
  "error": "Unauthorized",
  "timestamp": "2026-03-17T08:00:00.000Z",
  "path": "/auth/login/phone",
  "method": "POST"
}
```

---

## Users 模块

用户管理接口

| HTTP 方法 | 路径 | 描述 | 权限 |
| --- | --- | --- | --- |
| POST | /users | 创建用户 | 🎭 SUPER_ADMIN, STAFF |
| GET | /users | 获取用户列表 | 🎭 SUPER_ADMIN, STAFF |
| GET | /users/me | 获取当前用户信息 | ✅ |
| PUT | /users/me | 更新当前用户信息 | ✅ |
| DELETE | /users/me | 注销当前用户账号 | ✅ |
| GET | /users/me/pets | 获取当前用户的宠物列表 | ✅ |
| GET | /users/phone/:phone/pets | 根据手机号查询宠物列表 | 🎭 SUPER_ADMIN, DOCTOR |
| GET | /users/hospital/:hospitalId/staff | 获取医院员工列表 | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN, STAFF |
| GET | /users/:id/with-pets | 获取用户信息和宠物列表 | 🎭 DOCTOR, SUPER_ADMIN, HOSPITAL_ADMIN, STAFF |
| GET | /users/:id | 获取用户详情 | ✅ |
| PUT | /users/:id | 更新用户信息 | 🎭 SUPER_ADMIN, STAFF |
| POST | /users/:id/balance/adjust | 调整用户可用余额 | 🎭 SUPER_ADMIN, STAFF |
| GET | /users/:id/wallet-transactions | 获取用户钱包明细 | 🎭 SUPER_ADMIN, STAFF |
| DELETE | /users/:id | 删除用户 | 🎭 SUPER_ADMIN |

### 数据结构

```typescript
interface User {
  id: number
  username: string
  email?: string
  phone: string
  role: 'SUPER_ADMIN' | 'HOSPITAL_ADMIN' | 'STAFF' | 'DOCTOR' | 'USER'
  avatar?: string
  verified: boolean
  lastLoginAt?: string
  isActive: boolean
  hospitalId?: number
  remarks?: string
  balance?: number
  pendingBalance?: number
  createdAt: string
  updatedAt: string
}
```

### 更新用户请求说明

`PUT /users/:id` 支持管理员更新基础信息，也支持直接重置用户登录密码。

`POST /users`、`PUT /users/me` 和 `PUT /users/:id` 在写入 `username` 时会校验所有已启用敏感词。昵称包含任一敏感词（忽略英文字母大小写，并统一全角/半角字符）时返回 `400 Bad Request`，且不保存本次修改：

```json
{
  "statusCode": 400,
  "message": "昵称包含敏感词，请修改后重试"
}
```

**可选字段**：

- `username` - 用户名
- `phone` - 手机号
- `email` - 邮箱
- `role` - 角色
- `avatar` - 头像
- `isActive` - 启用状态
- `password` - 新登录密码（至少 6 位；传入时表示管理员重置该用户密码，后端会加密存储）

**示例请求**：

```json
{
  "username": "user001",
  "phone": "13800138000",
  "email": "user001@example.com",
  "isActive": true
}
```

### 注销当前用户账号

**端点:** `DELETE /users/me`

**描述:** 用户端自助注销当前登录账号。接口会将账号身份信息匿名化并停用账号；订单等依法需要保留的业务记录继续保留关联 ID。

**认证:** 需要 `Authorization: Bearer <token>`

**成功响应 (200):**

```json
{
  "code": 0,
  "message": "Success",
  "data": null
}
```

**说明:**

- 注销后手机号、邮箱、头像、用户名等账号身份信息会被删除或匿名化
- 注销后旧 token 不再可用，客户端应清除本地登录态并回到未登录状态
- 已产生的订单、钱包流水等记录按业务和法务留存要求保留

---

### 管理员重置用户密码示例

```http
PUT /users/123
Content-Type: application/json

{
  "password": "newPassword123"
}
```

```json
{
  "password": "newPassword123"
}
```

### 调整用户可用余额

**端点:** `POST /users/:id/balance/adjust`

**描述:** 管理员手动增加或减少用户的可用余额。该操作不会影响 `pendingBalance`，并且会同步写入钱包明细记录。

**请求体：**

```json
{
  "type": "increase",
  "amount": 20.5,
  "remark": "管理员手动增加余额"
}
```

**字段说明：**

- `type`: 调整类型，可选值 `increase` / `decrease`
- `amount`: 调整金额，单位元，最多保留 2 位小数
- `remark`: 备注，选填，最大 200 字

**响应示例：**

```json
{
  "code": 0,
  "data": {
    "id": 123,
    "username": "user001",
    "phone": "13800138000",
    "balance": 120.5,
    "pendingBalance": 0
  },
  "message": "Success"
}
```

### 获取用户钱包明细

**端点:** `GET /users/:id/wallet-transactions`

**描述:** 管理员查看指定用户的钱包流水，支持分页和类型/状态筛选。

**查询参数：**

- `page`: 页码，默认 `1`
- `limit`: 每页数量，默认 `10`
- `type`: 交易类型，可选 `income` / `expense` / `freeze` / `unfreeze`
- `status`: 交易状态，可选 `pending` / `approved` / `rejected`

**响应示例：**

```json
{
  "code": 0,
  "data": [
    {
      "id": 1,
      "userId": 123,
      "type": "income",
      "amount": 20.5,
      "balanceBefore": 100,
      "balanceAfter": 120.5,
      "relatedType": "recharge",
      "relatedId": 99,
      "status": "approved",
      "remark": "管理员手动增加余额",
      "reviewedAt": "2026-03-17T08:00:00.000Z",
      "reviewedBy": 99,
      "createdAt": "2026-03-17T08:00:00.000Z"
    }
  ],
  "pagination": {
    "total": 1,
    "page": 1,
    "pageSize": 10,
    "limit": 10,
    "totalPages": 1
  },
  "message": "Success"
}
```

---

## Pets 模块

宠物档案管理

| HTTP 方法 | 路径                  | 描述                 | 权限                          |
| --------- | --------------------- | -------------------- | ----------------------------- |
| POST      | /pets                 | 创建宠物档案         | 🎭 SUPER_ADMIN, STAFF, USER   |
| GET       | /pets                 | 获取宠物列表（分页） | 🎭 SUPER_ADMIN, STAFF, DOCTOR |
| GET       | /pets/my              | 获取我的宠物列表     | 🎭 USER                       |
| GET       | /pets/search/:keyword | 搜索宠物             | 🎭                            |
| GET       | /pets/statistics      | 获取宠物统计信息     | 🎭                            |
| GET       | /pets/my/statistics   | 获取我的宠物统计     | 🎭 USER                       |
| GET       | /pets/:id             | 获取宠物详情         | 🎭                            |
| PUT       | /pets/:id             | 更新宠物信息         | 🎭                            |
| DELETE    | /pets/:id             | 删除宠物（软删除）   | 🎭                            |
| POST      | /pets/:id/care-plan   | 手动触发生成护理计划 | 🎭 USER, SUPER_ADMIN, STAFF   |

**删除说明**:

- 删除宠物时会先清空 `categoryId` 和 `subCategoryId`，再执行软删除
- 这样可以保留宠物历史档案，同时避免软删除宠物继续阻止后台删除分类

### 数据结构（2026-01-23 重构后）

#### Pet

```typescript
{
  id: number
  name: string                      // 宠物名称
  avatar?: string                   // 宠物头像URL
  categoryId?: number               // 一级分类ID（类型）
  subCategoryId?: number            // 二级分类ID（种类）
  category?: PetCategory            // 一级分类对象
  subCategory?: PetCategory         // 二级分类对象
  gender: number                    // 性别：1=弟弟，2=妹妹
  birthDate?: string                // 出生日期（YYYY-MM-DD）
  weight?: number                   // 体重（kg）
  tags?: string[]                   // 标签数组（如：["疫苗齐全", "慢性病"]）
  isNeutered?: boolean              // 是否绝育
  vaccineCount?: number             // 已接种疫苗针数
  ownerId: number                   // 拥有者ID
  owner?: User                      // 拥有者对象
  appointmentCount: number          // 预约次数
  consultationCount: number         // AI问诊次数

  // 护理计划相关（2026-01-26 新增）
  carePlan?: object                 // 护理计划（包含 nutrition_plan 和 care_plan）
  carePlanStatus: string            // 状态：NOT_GENERATED=未生成，GENERATING=生成中，COMPLETED=已完成，FAILED=失败
  carePlanJobId?: string            // 队列任务 ID
  carePlanGeneratedAt?: string      // 最后生成时间
  carePlanError?: string            // 生成失败的错误信息

  createdAt: string
  updatedAt: string
}
```

#### PetGender（性别枚举）

```typescript
enum PetGender {
  MALE = 1, // 弟弟
  FEMALE = 2 // 妹妹
}
```

### 请求示例

#### 创建宠物（POST /pets）

```json
{
  "name": "旺财",
  "avatar": "/uploads/pets/avatar.jpg",
  "categoryId": 1,
  "subCategoryId": 5,
  "gender": 1,
  "birthDate": "2020-01-01",
  "weight": 10.5,
  "vaccineCount": 3,
  "tags": ["疫苗齐全", "慢性病"],
  "isNeutered": false,
  "ownerId": 123
}
```

#### 更新宠物（PUT /pets/:id）

```json
{
  "name": "旺财",
  "avatar": "/uploads/pets/new-avatar.jpg",
  "categoryId": 2,
  "subCategoryId": 8,
  "gender": 1,
  "birthDate": "2020-01-01",
  "weight": 12.5,
  "vaccineCount": 4,
  "tags": ["疫苗齐全"],
  "isNeutered": true
}
```

#### 获取宠物列表（GET /pets）

**查询参数**：

- `page` - 页码（默认 1）
- `pageSize` - 每页数量（默认 10）
- `name` - 宠物名称（模糊搜索）
- `categoryId` - 一级分类 ID
- `subCategoryId` - 二级分类 ID
- `gender` - 性别（1 或 2）
- `ownerId` - 拥有者 ID
- `minWeight` - 最小体重
- `maxWeight` - 最大体重
- `tags` - 标签（逗号分隔）
- `isNeutered` - 是否绝育
- `sortBy` - 排序字段（默认 createdAt）
- `sortOrder` - 排序方向（ASC/DESC，默认 DESC）

**响应示例**：

```json
{
  "code": 0,
  "data": [
    {
      "id": 1,
      "name": "旺财",
      "avatar": "/uploads/pets/avatar.jpg",
      "categoryId": 1,
      "subCategoryId": 5,
      "category": {
        "id": 1,
        "name": "狗",
        "parentId": null
      },
      "subCategory": {
        "id": 5,
        "name": "金毛",
        "parentId": 1
      },
      "gender": 1,
      "birthDate": "2020-01-01",
      "weight": 10.5,
      "tags": ["疫苗齐全"],
      "isNeutered": false,
      "ownerId": 123,
      "owner": {
        "id": 123,
        "username": "user001",
        "phone": "13800138000"
      },
      "appointmentCount": 5,
      "consultationCount": 2,
      "createdAt": "2024-01-01T00:00:00.000Z",
      "updatedAt": "2024-01-15T10:30:00.000Z"
    }
  ],
  "pagination": {
    "total": 100,
    "page": 1,
    "pageSize": 10,
    "totalPages": 10
  },
  "message": "Success"
}
```

#### 获取宠物统计（GET /pets/statistics）

**响应示例**：

```json
{
  "code": 0,
  "data": {
    "total": 500,
    "byCategory": {
      "1": 200, // 狗
      "2": 250 // 猫
    },
    "byGender": {
      "1": 280, // 弟弟
      "2": 220 // 妹妹
    }
  },
  "message": "Success"
}
```

### 重构说明（2026-01-23）

#### 移除字段

- ❌ `type` - 类型枚举（改用 categoryId）
- ❌ `breed` - 品种（改用 subCategoryId）
- ❌ `notes` - 备注
- ❌ `medicalHistory` - 既往病史
- ❌ `allergies` - 过敏史

#### 新增字段

- ✅ `categoryId` - 一级分类 ID（类型）
- ✅ `subCategoryId` - 二级分类 ID（种类）
- ✅ `category` - 一级分类对象（关联查询）
- ✅ `subCategory` - 二级分类对象（关联查询）

#### 修改字段

- 🔄 `gender` - 从字符串枚举（'male'/'female'）改为数字（1/2）
  - 1 = 弟弟（原 'male'）
  - 2 = 妹妹（原 'female'）

### 护理计划功能（2026-01-26 新增）

#### 手动触发生成护理计划（POST /pets/:id/care-plan）

**描述**: 手动触发生成宠物的护理计划（营养计划和护理计划）

**权限**: USER（宠物主人）、SUPER_ADMIN、STAFF

**路径参数**:

- `id` - 宠物 ID

**响应示例**:

```json
{
  "code": 0,
  "message": "护理计划生成任务已启动",
  "data": {
    "petId": 123,
    "status": "GENERATING",
    "jobId": "456"
  }
}
```

**说明**:

- 护理计划生成是异步的，需要等待队列处理完成
- 生成时间可能需要 1-2 分钟
- 前端应定期刷新宠物详情，检查 `carePlanStatus` 状态
- 状态说明：
  - `NOT_GENERATED`: 未生成
  - `GENERATING`: 生成中
  - `COMPLETED`: 已完成
  - `FAILED`: 生成失败

**自动触发场景**:

- 创建宠物时自动生成
- 修改以下字段时自动重新生成：
  - `weight`（体重）
  - `isNeutered`（绝育状态）
  - `birthDate`（年龄）
  - `gender`（性别）
  - `subCategoryId`（品种）

#### 护理计划数据结构

```typescript
{
  carePlan: {
    pet_info: {
      name: string
      species: string
      breed: string
      age: string
      weight: number
      sex: string
      neutered: boolean
    }
    nutrition_plan: {
      daily_calories: number           // 每日卡路里需求
      macro_ratio: {
        protein: number                // 蛋白质比例
        fat: number                    // 脂肪比例
        carbs: number                  // 碳水化合物比例
      }
      recommended_foods: string[]      // 推荐食物
      avoid_foods: string[]            // 避免的食物
      supplements: string[]            // 营养补充剂
      feeding_schedule: string[]       // 喂养时间表
    }
    care_plan: {
      grooming: Array<{                // 美容护理
        type: string
        frequency: string
        notes: string
      }>
      medical: Array<{                 // 医疗护理
        type: string
        frequency: string
        notes: string
      }>
      exercise: Array<{                // 运动建议
        type: string
        duration: string
        frequency: string
      }>
      vaccination: Array<{            // 疫苗接种
        name: string
        schedule: string
      }>
      environment: Array<{             // 环境管理
        aspect: string
        recommendation: string
      }>
    }
    validation: {
      risk_analysis: string            // 风险分析
      contradictions: any[]             // 矛盾点
    }
  }
}
```

**返回结构说明**:

- 成功响应统一为 `{ code, data, message, pagination? }`
- 业务失败统一返回 HTTP `200`，并使用 `{ success: false, code, statusCode, message, error, ... }` 表示失败；rnapp/admin 均不得再依赖非 200 HTTP 状态码判断业务是否成功
- rnapp 调用该接口时应读取最外层 `data` 作为公益数组
- 分页信息位于最外层 `pagination`；请优先使用 `pagination.total`、`pagination.page`、`pagination.totalPages`
- 页大小请以前端请求参数 `pageSize` 为准；若运行时额外出现 `pagination.limit`，可视为 `pageSize` 的同义字段

---

## Pet Categories 模块

宠物类别管理（两级分类体系）

| HTTP 方法 | 路径 | 描述 | 权限 |
| --- | --- | --- | --- |
| POST | /pet-categories | 创建宠物类别 | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN, STAFF |
| GET | /pet-categories | 获取类别列表（平铺） | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN, STAFF |
| GET | /pet-categories/tree | 获取分类树（支持搜索） | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN, STAFF |
| GET | /pet-categories/:id | 获取类别详情 | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN, STAFF |
| PUT | /pet-categories/:id | 更新类别信息 | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN, STAFF |
| DELETE | /pet-categories/:id | 删除类别（级联删除子分类） | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN, STAFF |

### 数据结构

#### PetCategory

```typescript
{
  id: number
  name: string // 分类名称
  parentId: number | null // 父级分类ID（一级分类为null）
  sortOrder: number // 排序序号（越小越靠前）
  createdAt: string // 创建时间
  updatedAt: string // 更新时间
}
```

#### PetCategoryTreeNode（树形结构）

```typescript
{
  id: number
  name: string
  parentId: number | null
  sortOrder: number
  createdAt: string
  updatedAt: string
  children?: PetCategoryTreeNode[]  // 子分类
}
```

### 请求示例

```typescript
// 获取分类树
GET /pet-categories/tree?name=金

// 响应
{
  "code": 0,
  "data": [
    {
      "id": 1,
      "name": "狗",
      "parentId": null,
      "sortOrder": 1,
      "createdAt": "2024-01-01T00:00:00.000Z",
      "updatedAt": "2024-01-01T00:00:00.000Z",
      "children": [
        {
          "id": 11,
          "name": "金毛",
          "parentId": 1,
          "sortOrder": 1,
          "createdAt": "2024-01-01T00:00:00.000Z",
          "updatedAt": "2024-01-01T00:00:00.000Z",
          "children": []
        }
      ]
    }
  ],
  "message": "Success"
}

// 创建一级分类
POST /pet-categories
{
  "name": "狗",
  "parentId": null,
  "sortOrder": 1
}

// 创建二级分类
POST /pet-categories
{
  "name": "金毛",
  "parentId": 1,
  "sortOrder": 1
}

// 更新分类
PUT /pet-categories/11
{
  "name": "金毛寻回犬",
  "sortOrder": 2
}

// 删除分类（级联删除子分类）
DELETE /pet-categories/1
// 响应：删除 id=1 的分类及其所有子分类
{
  "code": 0,
  "data": {
    "affected": 5  // 删除的总数（包括子分类）
  },
  "message": "Success"
}
```

### 业务规则

1. **同一父级下分类名称必须唯一**
   - 如果尝试创建重复名称，会返回错误：`同一父级下分类名称已存在`

2. **防止循环引用**
   - 不能将分类的 `parentId` 设置为自己
   - 不能将分类的 `parentId` 设置为自己的子孙分类

3. **级联删除**
   - 删除一级分类时，会自动删除其下所有二级分类
   - 删除前请确认子分类数量

4. **删除前会校验宠物引用**
   - 如果当前分类或子分类仍被有效宠物引用，会返回错误：`当前分类下仍有 X 条宠物档案引用，请先调整宠物分类或删除宠物后再删除分类`
   - 如果只有已删除宠物仍在引用，也会返回错误：`当前分类下存在 X 条已删除的宠物档案引用。由于宠物删除为软删除，请先清理相关宠物数据后再删除分类`

---

## Hospitals 模块

医院管理

| HTTP 方法 | 路径                  | 描述                       | 权限                           |
| --------- | --------------------- | -------------------------- | ------------------------------ |
| POST      | /hospitals            | 创建医院                   | 🎭 SUPER_ADMIN                 |
| GET       | /hospitals            | 获取医院列表               | 🌐                             |
| GET       | /hospitals/nearby     | 获取附近医院（按距离排序） | 🌐                             |
| GET       | /hospitals/statistics | 获取医院统计               | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN |
| GET       | /hospitals/:id        | 获取医院详情               | 🌐                             |
| PUT       | /hospitals/:id        | 更新医院信息               | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN |
| DELETE    | /hospitals/:id        | 删除医院                   | 🎭 SUPER_ADMIN                 |

### 获取附近医院（GET /hospitals/nearby）

**描述**: 根据用户经纬度获取距离最近的医院列表，按距离升序排列，使用 Redis 缓存（1 小时）

**查询参数**: | 参数 | 类型 | 必填 | 描述 | 示例 | |------|------|------|------|------| | latitude | number | 是 | 纬度（-90 ~ 90） | 39.9042 | | longitude | number | 是 | 经度（-180 ~ 180） | 116.4074 | | limit | number | 否 | 返回数量（默认 10，最大 50） | 10 |

**请求示例**:

```
GET /hospitals/nearby?latitude=39.9042&longitude=116.4074&limit=10
```

**响应示例**:

```json
{
  "success": true,
  "statusCode": 200,
  "data": [
    {
      "id": 1,
      "name": "爱宠宠物医院",
      "logo": "https://example.com/logo.png",
      "description": "专业宠物医疗服务",
      "province": "北京市",
      "city": "北京市",
      "county": "朝阳区",
      "address": "北京市朝阳区望京街道阜通东大街6号院",
      "phone": "010-12345678",
      "email": "contact@example.com",
      "latitude": 39.905,
      "longitude": 116.408,
      "status": "active",
      "businessStatusText": "营业中",
      "rating": 4.5,
      "reviewCount": 128,
      "distance": 1.2,
      "facilities": "[\"急诊\", \"手术\", \"住院\"]"
    }
  ],
  "meta": {
    "timestamp": "2025-01-26T10:30:00.000Z"
  }
}
```

**说明**:

- 使用 Haversine 公式计算球面距离
- 距离单位为公里，保留两位小数
- `businessStatusText` 为前端友好的状态文本
- 结果使用 Redis 缓存 1 小时（基于 Geohash）
- 不限制搜索半径，返回最近的 N 家医院
- 显示所有医院，不筛选营业状态

---

## Departments 模块

科室管理

| HTTP 方法 | 路径             | 描述         | 权限 |
| --------- | ---------------- | ------------ | ---- |
| POST      | /departments     | 创建科室     | ✅   |
| GET       | /departments     | 获取科室列表 | 🌐   |
| GET       | /departments/:id | 获取科室详情 | 🌐   |
| PUT       | /departments/:id | 更新科室     | ✅   |
| DELETE    | /departments/:id | 删除科室     | ✅   |

---

## Doctors 模块

医生管理（完全独立的账号系统）

### HTTP 接口

| HTTP 方法 | 路径 | 描述 | 权限 |
| --- | --- | --- | --- |
| POST | /doctors | 创建医生资料 | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN, STAFF |
| GET | /doctors | 获取医生列表（支持分页和筛选） | 🌐 |
| GET | /doctors/statistics | 获取医生统计信息 | 🎭 |
| GET | /doctors/hospital/:hospitalId | 获取医院的医生列表 | 🌐 |
| GET | /doctors/department/:departmentId | 获取科室的医生列表 | 🌐 |
| GET | /doctors/:id | 获取医生详情 | 🌐 |
| PUT | /doctors/:id | 更新医生信息 | 🎭 |
| DELETE | /doctors/:id | 删除医生（软删除） | 🎭 SUPER_ADMIN |

### 医生认证接口

| HTTP 方法 | 路径                  | 描述             | 权限      |
| --------- | --------------------- | ---------------- | --------- |
| POST      | /doctors-auth/login   | 医生登录         | 🌐        |
| GET       | /doctors-auth/profile | 获取当前医生资料 | 🎭 DOCTOR |

### 医生收费项管理接口

| HTTP 方法 | 路径 | 描述 | 权限 |
| --- | --- | --- | --- |
| GET | /doctors/:id/service-items | 获取医生的收费项列表 | 🌐 |
| POST | /doctors/:id/service-items | 为医生添加收费项 | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN, STAFF |
| POST | /doctors/:id/service-items/batch | 批量添加收费项 | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN, STAFF |
| PUT | /doctors/:id/service-items/:itemId | 更新收费项 | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN, STAFF |
| DELETE | /doctors/:id/service-items/:itemId | 删除收费项 | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN, STAFF |

#### 收费项数据结构

```typescript
{
  id: number
  doctorId: number
  name: string          // 服务名称（如"图文咨询"）
  duration: number      // 服务时长（分钟）
  price: number         // 服务价格（元）
  description?: string  // 服务描述
  sortOrder: number     // 排序序号
  isActive: boolean     // 是否启用
  createdAt: string
  updatedAt: string
}
```

#### 添加收费项（POST /doctors/:id/service-items）

**请求参数**：

```json
{
  "name": "图文咨询",
  "duration": 30,
  "price": 50.0,
  "description": "24小时内图文咨询服务",
  "isActive": true
}
```

#### 批量添加收费项（POST /doctors/:id/service-items/batch）

**请求参数**：

```json
{
  "serviceItems": [
    {
      "name": "图文咨询",
      "duration": 30,
      "price": 50.0,
      "description": "24小时内图文咨询服务"
    },
    {
      "name": "电话咨询",
      "duration": 15,
      "price": 80.0,
      "description": "15分钟电话咨询服务"
    }
  ]
}
```

#### 更新收费项（PUT /doctors/:id/service-items/:itemId）

**请求参数**：

```json
{
  "name": "图文咨询（已更新）",
  "duration": 30,
  "price": 60.0,
  "isActive": true
}
```

### 创建医生（POST /doctors）

**必填字段**：

- `username` - 登录用户名（3-50 字符，唯一）
- `password` - 登录密码（至少 6 位）
- `phone` - 手机号（11 位，唯一）
- `name` - 医生姓名
- `specialty` - 专业领域
- `hospitalId` - 所属医院 ID
- `departmentId` - 所属科室 ID

**可选字段**：

- `avatar` - 头像 URL
- `description` - 医生简介
- `experience` - 从业经验（年，0-50）
- `isGoldDoctor` - 是否为金牌医师（默认 false）
- `isActive` - 是否在职（默认 true）
- `qualifications` - 资质证书
- `tags` - 标签数组

**示例请求**：

```json
{
  "username": "doctor001",
  "password": "123456",
  "phone": "13800138000",
  "name": "张医生",
  "specialty": "宠物内科",
  "experience": 10,
  "isGoldDoctor": true,
  "hospitalId": 1,
  "departmentId": 2
}
```

### 查询医生列表（GET /doctors）

**查询参数**：

- `page` - 页码（默认 1）
- `pageSize` - 每页数量（默认 10）
- `name` - 姓名模糊搜索
- `phone` - 手机号精确搜索
- `specialty` - 专长模糊搜索
- `hospitalId` - 按医院筛选
- `departmentId` - 按科室筛选
- `isActive` - 在职状态筛选
- `isGoldDoctor` - 金牌医师筛选
- `minRating` - 最低评分（0-5）
- `minExperience` - 最低经验年限
- `sortBy` - 排序字段（createdAt/updatedAt/name/rating/experience/consultationCount）

### 删除医生（DELETE /doctors/:id）

**说明**：

- 接口执行软删除，会更新 `deletedAt`。
- 删除前会将医生账号 `username` 改为原值增加 `del_` 前缀。
- 删除前会优先将 `phone` 改为原值增加 `00` 前缀；如果数据库不支持该写入，会改为在原值末尾增加 `00`。

### 医生登录（POST /doctors-auth/login）

**请求参数**：

```json
{
  "username": "doctor001",
  "password": "123456"
}
```

**返回数据**：

```json
{
  "success": true,
  "message": "登录成功",
  "data": {
    "access_token": "eyJhbGc...",
    "token_type": "Bearer",
    "doctor": {
      "id": 1,
      "name": "张医生",
      "username": "doctor001",
      "phone": "13800138000",
      "avatar": "...",
      "specialty": "宠物内科",
      "isGoldDoctor": true,
      "hospital": { ... },
      "department": { ... }
    }
  }
}
```

### 医生字段说明

- **账号信息**：
  - `username` - 登录用户名（唯一）
  - `password` - 登录密码（加密存储）
  - `phone` - 手机号（唯一）

- **基本信息**：
  - `name` - 姓名
  - `avatar` - 头像 URL
  - `specialty` - 专业领域
  - `description` - 简介
  - `experience` - 从业经验（年）
  - `rating` - 评分（0-5）
  - `isGoldDoctor` - 是否为金牌医师
  - `consultationCount` - 咨询次数，按该医生当前状态为 `PAID` 的咨询订单数实时统计
  - `isActive` - 是否在职
  - `lastLoginAt` - 最后登录时间

- **关联信息**：
  - `hospitalId` - 所属医院 ID
  - `departmentId` - 所属科室 ID

### 医生统计信息（GET /doctors/statistics）

`totalConsultations` 按统计范围内医生当前状态为 `PAID` 的咨询订单总数计算。

**返回数据**：

```json
{
  "totalDoctors": 100,
  "avgRating": "4.5",
  "totalConsultations": 5000,
  "activeDoctors": 95,
  "goldDoctors": 20,
  "byDepartment": [
    { "departmentName": "内科", "count": 30 },
    { "departmentName": "外科", "count": 25 }
  ]
}
```

---

## Schedules 模块

排班管理

| HTTP 方法 | 路径                                 | 描述         | 权限                  |
| --------- | ------------------------------------ | ------------ | --------------------- |
| POST      | /schedules                           | 创建排班     | 🎭 SUPER_ADMIN, STAFF |
| GET       | /schedules                           | 获取排班列表 | 🌐                    |
| GET       | /schedules/doctor/:doctorId          | 获取医生排班 | 🌐                    |
| GET       | /schedules/available/:doctorId/:date | 获取可用时段 | 🌐                    |
| GET       | /schedules/:id                       | 获取排班详情 | 🌐                    |
| PUT       | /schedules/:id                       | 更新排班     | 🎭                    |
| DELETE    | /schedules/:id                       | 删除排班     | 🎭                    |

---

## Appointments 模块

预约管理

| HTTP 方法 | 路径 | 描述 | 权限 |
| --- | --- | --- | --- |
| POST | /appointments | 创建预约 | 🎭 USER |
| GET | /appointments | 获取预约列表 | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN, STAFF, DOCTOR |
| GET | /appointments/my | 获取我的预约 | 🎭 USER |
| GET | /appointments/doctor | 获取医生预约 | 🎭 DOCTOR |
| GET | /appointments/hospital | 获取医院预约 | 🎭 HOSPITAL_ADMIN, STAFF |
| GET | /appointments/statistics | 获取预约统计 | 🎭 |
| GET | /appointments/:id | 获取预约详情 | 🎭 |
| PUT | /appointments/:id | 更新预约 | 🎭 |
| POST | /appointments/:id/confirm | 确认预约 | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN, STAFF |
| DELETE | /appointments/:id | 取消预约 | 🎭 |

### 预约状态

- PENDING - 待确认
- CONFIRMED - 已确认
- CANCELLED - 已取消
- COMPLETED - 已完成

---

## AI Consultation 模块

AI 问诊

| HTTP 方法 | 路径                        | 描述             | 权限                          |
| --------- | --------------------------- | ---------------- | ----------------------------- |
| POST      | /ai-consultation/ask        | 发起 AI 问诊     | 🎭                            |
| GET       | /ai-consultation            | 获取问诊记录     | 🎭 SUPER_ADMIN, STAFF, DOCTOR |
| GET       | /ai-consultation/history    | 获取我的问诊历史 | 🎭 USER                       |
| GET       | /ai-consultation/statistics | 获取问诊统计     | 🎭                            |
| GET       | /ai-consultation/:id        | 获取问诊详情     | 🎭                            |

---

## Chat 模块

聊天系统

**架构更新说明（2026-01-21）**：

- ✅ 套餐管理已迁移到 `DoctorServiceItem`（医生收费项）
- ✅ 订单创建使用 `serviceItemId` 替代 `packageId`
- ⚠️ 旧的 `/chat/packages` 接口已废弃，请使用 Doctors 模块的收费项接口

**会话 contract 更新说明（2026-04-22）**：

- ✅ `conversationId` 现在是 `chat_sessions` 表里的**会话级持久化标识**
- ✅ `GET /chat/session/:doctorId` 与兼容接口 `GET /chat/conversation-id` 都返回服务端解析出的真实 session `conversationId`
- ✅ 新增 `GET /chat/previous-session/:doctorId?beforeConversationId=...`，用于按段回捞上一段历史会话元数据
- ⚠️ 任何客户端都**不能再把 `conversationId` 当成 `userId_doctorId`**，也不能再本地拼接 / 拆分这个值

**全局消息监听更新说明（2026-07-27）**：

- WebSocket 鉴权成功后自动加入按账号类型隔离的个人房间：`chat:user:<id>` 或 `chat:doctor:<id>`
- 新咨询消息除继续发送会话内 `newMessage` 外，还会向实际接收者发送个人事件 `chat:message:new`
- `GET /chat/unread-count` 同时统计 MySQL 付费消息和 Redis 免费阶段消息，并按 `user / doctor` 接收者类型隔离；用户端只统计当前咨询列表仍可展示的会话
- `GET /chat/conversations` 返回当前用户的医生咨询消息列表，统一合并免费临时会话与付费/历史会话
- 新增整段会话已读接口；服务端只使用当前 JWT 身份，不接受客户端指定代操作用户

### HTTP 接口

| HTTP 方法 | 路径 | 描述 | 权限 |
| --- | --- | --- | --- |
| GET | /chat/session/:doctorId | 获取会话状态 | ✅ |
| GET | /chat/conversation-id | 兼容接口：解析当前会话ID | ✅ |
| GET | /chat/previous-session/:doctorId | 获取上一段历史会话元数据 | ✅ |
| GET | /chat/messages | 获取消息历史（用户和医生校验会话参与关系，管理员保留审计读取） | 🎭 USER, DOCTOR, SUPER_ADMIN, HOSPITAL_ADMIN, STAFF |
| POST | /chat/messages/:id/revoke | 撤回本人 2 分钟内发送的普通医患消息 | 🎭 USER, DOCTOR |
| GET | /chat/message/:id | 获取消息详情 | ✅ |
| GET | /chat/ai-consultations/:petId | 获取宠物 AI 问诊记录 | ✅ |
| GET | /chat/statistics | 获取聊天统计 | 🎭 |
| GET | /chat/packages/:doctorId | 获取可用套餐（查询医生收费项） | ✅ |
| POST | /chat/orders | 创建订单（购买医生收费项） | 🎭 USER |
| GET | /chat/orders | 我的订单列表 | 🎭 USER |
| GET | /chat/history-consultations | 获取当前用户的历史咨询列表 | 🎭 USER |
| GET | /chat/doctor/sessions/:conversationId/history | 医生查看当前用户的历史咨询会话 | 🎭 DOCTOR |
| GET | /chat/doctor/sessions/:conversationId/history/:historyConversationId/messages | 医生查看某次历史咨询的只读消息 | 🎭 DOCTOR |
| POST | /chat/doctor/sessions/:conversationId/extensions | 医生主动延长当前付费咨询时间 | 🎭 DOCTOR |
| GET | /chat/orders/:orderNo | 订单详情 | ✅ |
| POST | /chat/auto-replies | 创建自动回复 | 🎭 SUPER_ADMIN, DOCTOR |
| PUT | /chat/auto-replies/:id | 更新自动回复 | 🎭 |
| DELETE | /chat/auto-replies/:id | 删除自动回复 | 🎭 |
| GET | /chat/auto-replies | 获取自动回复列表 | ✅ |
| ~~POST~~ | ~~~/chat/packages~~ | ~~创建套餐~~（已废弃，使用 `/doctors/:doctorId/service-items`） | ~~- |
| ~~PUT~~ | ~~~/chat/packages/:id~~ | ~~更新套餐~~（已废弃，使用 `/doctors/:doctorId/service-items/:id`） | ~~- |
| ~~DELETE~~ | ~~~/chat/packages/:id~~ | ~~删除套餐~~（已废弃，使用 `/doctors/:doctorId/service-items/:id`） | ~~- |
| GET | /chat/payment-config | 获取全局付费配置 | ✅ |
| GET | /chat/payment-config/:doctorId | 获取医生付费配置 | ✅ |
| PUT | /chat/payment-config/:doctorId | 更新付费配置 | 🎭 SUPER_ADMIN |
| GET | /chat/unread-count | 获取未读消息数 | ✅ |
| GET | /chat/conversations | 获取当前用户的医生咨询消息列表 | 🎭 USER |
| PUT | /chat/conversations/:conversationId/read | 标记当前账号在咨询会话中收到的消息已读 | 🎭 USER, DOCTOR |

#### 咨询消息列表、未读与整段已读

`GET /chat/conversations?page=1&limit=20` 仅供用户账号调用，`limit` 最大为 100。列表按最后消息时间倒序排列，同时包含 Redis 中的免费临时会话，以及 MySQL 中的付费和历史会话：

```json
{
  "data": [
    {
      "conversationId": "550e8400-e29b-41d4-a716-446655440000",
      "userId": 7,
      "doctorId": 10,
      "doctorName": "陈医生",
      "doctorAvatar": "/uploads/doctor.png",
      "status": "PAID",
      "paymentRequired": false,
      "isTemporary": false,
      "orderId": 71,
      "serviceStartAt": "2026-07-27T02:00:00.000Z",
      "serviceEndAt": "2026-07-30T02:00:00.000Z",
      "lastMessage": {
        "id": 101,
        "conversationId": "550e8400-e29b-41d4-a716-446655440000",
        "senderId": 10,
        "receiverId": 7,
        "content": "检查结果正常",
        "type": "TEXT",
        "isAutoReply": false,
        "createdAt": "2026-07-27T04:00:00.000Z"
      },
      "unreadCount": 2,
      "createdAt": "2026-07-27T01:00:00.000Z",
      "updatedAt": "2026-07-27T04:00:00.000Z"
    }
  ],
  "total": 1,
  "page": 1,
  "limit": 20,
  "totalPages": 1
}
```

`GET /chat/unread-count` 返回当前账号的咨询未读总数。响应数据为数字，包含免费阶段 Redis 临时消息和付费阶段 MySQL 消息。用户账号的统计范围与 `GET /chat/conversations` 保持一致，不包含已经找不到对应咨询会话的遗留消息或失效临时会话。

`PUT /chat/conversations/:conversationId/read` 无需请求体。当前 JWT 必须与该会话中的用户或医生身份严格匹配；成功响应：

```json
{
  "success": true
}
```

#### 创建订单（购买医生收费项）

**端点:** `POST /chat/orders`

**说明:** 创建待支付咨询订单并返回支付参数。支付宝支付时，后端仅在异步回调或主动查单确认成功后激活咨询会话；余额支付会在同一事务内完成扣款与会话激活。创建订单本身不会绕过支付直接开放聊天。

**请求体:**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `doctorId` | number | 是 | 医生 ID |
| `serviceItemId` | number | 是 | 医生收费项 ID |
| `paymentChannel` | `'alipay' \| 'balance'` | 是 | 支付渠道；当前咨询套餐支持支付宝和余额 |
| `idempotencyKey` | string (UUID v4) | 是 | 客户端生成的支付幂等键，同一次提交重试时必须保持不变 |
| `conversationId` | string | 否 | 当前聊天页的临时会话 ID。仅在“当前页直接付费并保留本次临时消息”时传入 |

**请求示例:**

```json
{
  "doctorId": 8,
  "serviceItemId": 21,
  "paymentChannel": "alipay",
  "idempotencyKey": "a93a2a65-b185-407c-9c75-bf91b2ca7e1a",
  "conversationId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**支付宝响应示例:**

```json
{
  "order": {
    "id": 71,
    "orderNo": "CO17856677501631234",
    "status": "PENDING",
    "amount": "50.00"
  },
  "paymentParams": {
    "paymentNo": "PAY178566775016380EB58EC",
    "outTradeNo": "CHAT_PACKAGE_71",
    "amount": 50,
    "channel": "alipay",
    "method": "app",
    "paymentParams": {
      "alipayOrderString": "app_id=..."
    },
    "expiredAt": "2026-08-02T11:15:00.000Z"
  }
}
```

余额支付成功时，响应中的 `order.status` 为 `PAID`，`paymentParams.paymentParams` 为空对象。客户端必须以服务端支付状态为准：仅在订单已支付或 `GET /payment/query/:paymentNo` 返回 `success` 后刷新会话并开放聊天；取消、失败或仍在处理中时不得激活会话。

### 会话接口更新

#### 1. 获取当前会话

**端点:** `GET /chat/session/:doctorId`

**说明:** 返回当前用户与指定医生当前有效会话的元数据。当前规则是：`FREE` 会话只存在于 Redis 临时存储；只有 `PAID / EXPIRED` 会话才会持久化到 `chat_sessions`。因此 `FREE` 会话的 `conversationId` 仍然是服务端生成的 opaque id，但 `sessionId` 可能为空。

**关键字段说明:**

| 字段             | 类型                            | 说明                                |
| ---------------- | ------------------------------- | ----------------------------------- |
| `sessionId`      | number \| undefined            | `PAID / EXPIRED` 会话对应的 `chat_sessions` 主键 |
| `conversationId` | string                          | 会话级持久化标识，opaque session id |
| `status`         | `'FREE' \| 'PAID' \| 'EXPIRED'` | 当前会话状态                        |
| `currentOrder`   | object \| null                  | 当前关联订单（如有）                |

#### 1.1 购买套餐时的会话保留规则

- 用户在**当前聊天页直接购买**时，请在 `POST /chat/orders` 请求体中带上当前 `conversationId`
- 只有支付成功且请求中的 `conversationId` 命中当前 Redis 临时会话时，后端才会把这段临时消息迁移到数据库并绑定到订单
- 如果用户在弹出付费提示后退出页面，再次进入会创建新的临时会话；旧临时消息不会保留
- 只有 `PAID` 会话在聊天页滚动到顶部时，才允许继续加载上一段已过期的付费历史会话

#### 2. 兼容接口：解析当前会话 ID

**端点:** `GET /chat/conversation-id`

**查询参数:**

| 参数       | 类型   | 必填 | 说明                            |
| ---------- | ------ | ---- | ------------------------------- |
| `doctorId` | number | 是   | 医生 ID                         |
| `userId`   | number | 是   | 用户 ID（兼容旧客户端保留参数） |

**响应示例:**

```json
{
  "conversationId": "550e8400-e29b-41d4-a716-446655440000"
}
```

> 说明：该接口现在只返回服务端解析出的真实 session `conversationId`，不再“生成” `userId_doctorId`。

#### 3. 获取上一段历史会话元数据

**端点:** `GET /chat/previous-session/:doctorId?beforeConversationId=...`

**查询参数:**

| 参数                   | 类型   | 必填 | 说明                              |
| ---------------------- | ------ | ---- | --------------------------------- |
| `beforeConversationId` | string | 是   | 当前会话的持久化 `conversationId` |

**响应示例:**

```json
{
  "sessionId": 201,
  "conversationId": "e7f0bb79-4db5-4b58-8b5b-efea1f59925d",
  "status": "EXPIRED",
  "orderId": 88,
  "serviceStartAt": "2026-04-01T10:00:00.000Z",
  "serviceEndAt": "2026-04-01T11:00:00.000Z",
  "createdAt": "2026-04-01T10:00:00.000Z",
  "updatedAt": "2026-04-01T11:00:00.000Z"
}
```

**权限说明:**

- 当前登录用户必须是 `beforeConversationId` 对应会话的参与者
- 只返回同一用户与同一医生之间、在当前会话之前最近的一段历史会话
- 该接口只返回 session 元数据；历史消息仍通过 `GET /chat/messages?conversationId=` 拉取

### 医疗服务订单接口（移动端使用）

| HTTP 方法 | 路径         | 描述                           | 权限    |
| --------- | ------------ | ------------------------------ | ------- |
| GET       | /chat/orders | 获取当前用户的医疗服务订单列表 | ✅ USER |

#### 请求参数

| 参数     | 类型   | 必填 | 描述                       |
| -------- | ------ | ---- | -------------------------- |
| page     | number | 否   | 页码，默认 1               |
| pageSize | number | 否   | 每页数量，默认 10，最大 20 |

#### 响应示例

```json
{
  "data": [
    {
      "id": 1,
      "orderNo": "CO17379284601234",
      "userId": 1,
      "doctorId": 5,
      "serviceItemId": 10,
      "durationMinutes": 30,
      "amount": 50.0,
      "status": "PAID",
      "paidAt": "2024-01-15T14:28:00Z",
      "serviceStartAt": "2024-01-15T14:28:00Z",
      "serviceEndAt": "2024-01-15T14:58:00Z",
      "createdAt": "2024-01-15T14:28:00Z",
      "doctor": {
        "id": 5,
        "name": "张医生",
        "avatar": "https://example.com/avatar.jpg",
        "department": "内科"
      },
      "serviceItem": {
        "id": 10,
        "name": "图文咨询",
        "duration": 30,
        "price": 50.0
      }
    }
  ],
  "total": 100,
  "page": 1,
  "pageSize": 20,
  "totalPages": 5
}
```

#### 订单状态说明

| 状态      | 描述   |
| --------- | ------ |
| PENDING   | 待支付 |
| PAID      | 已支付 |
| REFUNDED  | 已退款 |
| EXPIRED   | 已过期 |
| CANCELLED | 已取消 |

### 历史咨询列表接口

**端点:** `GET /chat/history-consultations`

**描述:** 获取当前登录用户的已支付历史咨询记录，按支付时间倒序返回；传入 `doctorId` 时仅返回当前用户与指定医生的记录。`lastMessage` 现在会同时返回消息 `type`，客户端可据此将图片消息显示为 `[图片]`、视频消息显示为 `[视频]` 等预览文案，而不是直接展示资源 URL。

#### 查询参数

| 参数  | 类型   | 必填 | 描述               |
| ----- | ------ | ---- | ------------------ |
| page  | number | 否   | 页码，默认 `1`     |
| limit | number | 否   | 每页数量，默认 `3` |
| doctorId | number | 否 | 按医生ID筛选，仅返回当前用户与该医生的已支付订单 |

#### 响应示例

```json
{
  "data": [
    {
      "id": 101,
      "orderNo": "CHAT202603280001",
      "doctorId": 8,
      "doctorName": "李医生",
      "doctorAvatar": "/uploads/doctors/li.png",
      "lastMessage": {
        "id": 9001,
        "content": "https://cdn.example.com/chat/image.png",
        "type": "IMAGE",
        "createdAt": "2026-03-21T09:00:00.000Z"
      },
      "amount": 99,
      "status": "ACTIVE",
      "serviceStartAt": "2026-03-20T10:00:00.000Z",
      "serviceEndAt": "2026-03-30T10:00:00.000Z",
      "paidAt": "2026-03-20T10:00:00.000Z",
      "durationDays": 1
    }
  ],
  "pagination": {
    "total": 1,
    "page": 1,
    "pageSize": 3,
    "totalPages": 1
  }
}
```

#### `lastMessage.type` 可选值

| 值                | 描述         |
| ----------------- | ------------ |
| `TEXT`            | 文本消息     |
| `IMAGE`           | 图片消息     |
| `VIDEO`           | 视频消息     |
| `VOICE`           | 语音消息     |
| `SYSTEM`          | 系统消息     |
| `AI_CONSULTATION` | AI 问诊记录  |
| `PAYMENT_SUCCESS` | 支付成功消息 |
| `PAYMENT_PROMPT`  | 付费提示消息 |

#### 聊天媒体消息约定

- `sendMessage` / 聊天历史中的 `type` 现在支持 `VIDEO`
- 图片与视频消息都支持直接传资源 URL，或传结构化 JSON 字符串
- 推荐结构化 JSON 载荷如下：

```json
{
  "url": "/uploads/chat/abc123.mp4",
  "thumbnail": "/uploads/chat/abc123-cover.jpg",
  "width": 720,
  "height": 1280,
  "duration": 12,
  "fileName": "consultation.mp4",
  "mimeType": "video/mp4"
}
```

### WebSocket 接口

连接地址: `ws://localhost:3000`（本机联调示例；跨设备访问时请替换为可达地址）

连接成功后服务端自动把客户端加入个人房间。`leave` 只退出指定会话房间，不退出登录级个人房间。

| 方向 | 事件 | 描述 |
| --- | --- | --- |
| 客户端 → 服务端 | join | 加入指定咨询会话房间 |
| 客户端 → 服务端 | leave | 离开指定咨询会话房间 |
| 客户端 → 服务端 | sendMessage | 发送消息 |
| 客户端 → 服务端 | sendAiConsultation | 转发 AI 问诊 |
| 客户端 → 服务端 | revokeMessage | 撤回本人 2 分钟内发送的普通医患消息，载荷为 `conversationId` 与 `messageId` |
| 客户端 → 服务端 | markAsRead | 标记单条持久化消息已读 |
| 客户端 → 服务端 | markConversationAsRead | 标记当前账号在整段会话中收到的消息已读 |
| 客户端 → 服务端 | typing | 输入指示器 |
| 客户端 → 服务端 | getHistory | 获取消息历史 |
| 客户端 → 服务端 | getSession | 获取会话信息 |
| 客户端 → 服务端 | checkCanSend | 检查是否可发送消息 |
| 客户端 → 服务端 | getUnreadCount | 获取未读消息数 |
| 服务端 → 客户端 | newMessage | 指定会话房间的新消息，兼容聊天页实时收发 |
| 服务端 → 客户端 | chat:message:new | 当前账号作为接收者的新消息，用于登录级全局监听 |
| 服务端 → 客户端 | messageRevoked | 当前会话内消息已撤回，载荷为撤回后的消息对象 |
| 服务端 → 客户端 | chat:message:revoked | 登录级个人房间的消息撤回通知 |
| 服务端 → 客户端 | conversationRead | 整段会话已读确认 |
| 服务端 → 客户端 | auth:session:revoked | 当前登录会话已失效 |

---

## Shop 模块

商城管理

### 商品接口

| HTTP 方法 | 路径                       | 描述                           | 权限 |
| --------- | -------------------------- | ------------------------------ | ---- |
| GET       | /shop/products             | 获取商品列表                   | 🌐   |
| GET       | /shop/products/batch       | 批量获取商品（完整分类树）     | 🌐   |
| GET       | /shop/products/popular     | 获取热门商品列表               | 🌐   |
| GET       | /shop/homepage-banners     | 获取商城首页 Banner 配置       | 🌐   |
| GET       | /shop/products/:id         | 获取商品详情                   | 🌐   |
| GET       | /shop/products/:id/detail  | 获取商品详情（兼容接口，可选返回收藏状态） | 🌐   |
| GET       | /shop/products/:id/skus    | 获取商品 SKU 列表              | 🌐   |
| GET       | /shop/products/categories/list | 获取二手商品分类           | 🌐   |
| POST      | /shop/products             | 创建商品                       | 🎭   |
| PUT       | /shop/products/:id         | 更新商品                       | 🎭   |
| DELETE    | /shop/products/:id         | 删除商品                       | 🎭   |
| POST      | /shop/products/pending     | 提交二手商品审核               | ✅   |
| PUT       | /shop/products/pending/:id | 编辑待审核二手商品并重新提交   | ✅   |
| GET       | /shop/products/pending/:id | 获取待审核商品详情（编辑回显） | ✅   |
| GET       | /shop/products/my          | 获取我发布的商品               | ✅   |

**查询参数**:

> 商品列表、热门商品、商品详情、商品 SKU、商城 Banner 与二手商品分类均支持游客访问；未携带 Token 时，用户相关状态（如收藏）按未登录状态返回。购物车、订单、收藏和商品发布仍需登录。

```typescript
// GET /shop/products
{
  page?: number        // 页码，默认 1
  pageSize?: number    // 每页数量，默认 10，最大 100
  keyword?: string     // 搜索关键词（商品名称 + 分类名称，分类按 LIKE 匹配；匹配到分类时会包含其全部子分类下的商品）
  categoryId?: number  // 分类ID（传入任意层级分类ID时，都会递归返回该分类及全部后代分类下的商品）
  publishSource?: 'ADMIN' | 'USER'  // 发布来源
  minPrice?: number    // 最低价格
  maxPrice?: number    // 最高价格
  publishedBy?: number // 发布者ID
  isActive?: boolean   // 是否上架
  sortBy?: string      // 排序字段，默认 createdAt
  sortOrder?: 'ASC' | 'DESC'  // 排序方向，默认 DESC
}
```

### 商城首页配置接口

#### 用户端首页配置读取

| HTTP 方法 | 路径 | 描述 | 权限 |
| --- | --- | --- | --- |
| GET | /shop/products/popular | 获取首页热门商品（已配置时按配置顺序返回；未配置时按默认热门规则返回） | 🌐 |
| GET | /shop/homepage-banners | 获取首页 Banner 列表 | 🌐 |

```typescript
// GET /shop/products/popular
{
  page?: number
  pageSize?: number
  categoryId?: number
  minPrice?: number
  maxPrice?: number
  sortBy?: string
  sortOrder?: 'ASC' | 'DESC'
}

// GET /shop/homepage-banners
// 响应
{
  banners: Array<{
    id: string
    imageUrl: string
    actionType: 'none' | 'product'
    productId?: number
    sortOrder: number
  }>
}
```

#### 后台首页配置管理

| HTTP 方法 | 路径 | 描述 | 权限 |
| --- | --- | --- | --- |
| GET | /admin/shop/homepage-hot-products | 获取商城首页热门商品配置 | 🎭 SUPER_ADMIN / STAFF / HOSPITAL_ADMIN |
| PUT | /admin/shop/homepage-hot-products | 更新商城首页热门商品配置 | 🎭 SUPER_ADMIN / STAFF / HOSPITAL_ADMIN |
| GET | /admin/shop/homepage-banners | 获取商城首页 Banner 配置 | 🎭 SUPER_ADMIN / STAFF / HOSPITAL_ADMIN |
| PUT | /admin/shop/homepage-banners | 更新商城首页 Banner 配置 | 🎭 SUPER_ADMIN / STAFF / HOSPITAL_ADMIN |

```typescript
// PUT /admin/shop/homepage-hot-products
{
  productIds: number[] // 热门商品 ID 列表，按数组顺序展示
}

// GET /admin/shop/homepage-hot-products
{
  productIds: number[]
}

// PUT /admin/shop/homepage-banners
{
  banners: Array<{
    id?: string
    imageUrl: string
    actionType?: 'none' | 'product'
    productId?: number
    sortOrder?: number
  }>
}

// GET /admin/shop/homepage-banners
{
  banners: Array<{
    id: string
    imageUrl: string
    actionType: 'none' | 'product'
    productId?: number
    sortOrder: number
  }>
}
```

**商品返回补充字段**:

- 用户发布商品会返回 `publishSource: "USER"`。
- 商品列表、热门商品、商品详情、分类树商品节点均会尽量返回 `publisher` 信息；前端可展示为 `xxx 发布的商品`。
- 当 `publisher.nickname` 不存在时，可回退使用 `publisher.username` 或脱敏手机号。

**用户发布二手商品提交 / 编辑参数**:

```typescript
// POST /shop/products/pending
// PUT /shop/products/pending/:id
{
  title: string          // 商品标题，最多 50 字
  description: string    // 商品描述
  price: number          // 价格，必须大于 0
  stock?: number         // 库存，默认 1，最小 1，必须为整数
  images: string[]       // 商品图片数组
  categoryId: number     // 二级分类 ID
  condition: 'new' | '90%' | '80%' | '70%' | '60%'
  negotiable: boolean    // 是否可议价
  shippingFee: number    // 运费
}
```

**获取待审核商品详情（编辑回显）响应补充字段**:

- 返回结构与“我发布的商品”一致，新增 `stock` 字段。
- 如果历史数据未写入库存，服务端会兜底返回并按 `1` 处理。

**批量获取商品接口（完整分类树）**:

```typescript
// GET /shop/products/batch
// 描述: 返回所有一级分类、二级分类及商品的完整树形结构，前端自行处理展示逻辑
{
  includeEmpty?: boolean      // 是否包含空商品的分类（默认 false）
  limit?: number              // 每个分类最多返回的商品数量（0 表示全部，默认 50）
  sortBy?: string             // 排序字段，默认 sortOrder（可选: isTop, isHot, price, name）
  sortOrder?: 'ASC' | 'DESC'  // 排序方向，默认 ASC
}
```

**响应示例**:

```json
{
  "data": [
    {
      "id": 1,
      "name": "宠物食品",
      "icon": "https://...",
      "image": "https://...",
      "sortOrder": 1,
      "children": [
        {
          "id": 11,
          "name": "狗粮",
          "icon": "https://...",
          "image": "https://...",
          "sortOrder": 1,
          "products": [
            {
              "id": 101,
              "name": "皇家狗粮",
              "categoryId": 11,
              "price": 299.00,
              "isActive": true,
              "skus": [...]
            }
          ]
        }
      ]
    }
  ]
}
```

### 用户端二手商品发布接口

| HTTP 方法 | 路径                       | 描述                           | 权限   |
| --------- | -------------------------- | ------------------------------ | ------ |
| POST      | /shop/products/pending     | 发布二手商品                   | `USER` |
| PUT       | /shop/products/pending/:id | 编辑待审核/已驳回商品          | `USER` |
| GET       | /shop/products/pending/:id | 获取待审核商品详情（编辑回显） | `USER` |

#### 发布/编辑商品请求体

```typescript
{
  title: string          // 商品标题，最多 50 字
  description: string    // 商品描述
  price: number          // 售价，必须大于 0
  stock?: number         // 库存，默认 1，最小 1，服务端会兜底规范化
  images: string[]       // 商品图片
  categoryId: number     // 二级分类 ID
  condition: 'new' | '90%' | '80%' | '70%' | '60%'
  negotiable: boolean    // RN 当前固定传 false
  shippingFee: number    // RN 当前固定传 0
}
```

#### 待审核商品详情响应新增字段

```typescript
{
  "id": 1,
  "title": "二手猫粮",
  "price": 88,
  "stock": 3,
  "status": "rejected",
  "rejectReason": "图片不清晰"
}
```

### 商品审核接口（后台管理）

| HTTP 方法 | 路径 | 描述 | 权限 |
| --- | --- | --- | --- |
| GET | /admin/shop/pending-products | 获取待审核商品列表 | 🎭 SUPER_ADMIN / STAFF / HOSPITAL_ADMIN |
| GET | /admin/shop/pending-products/:id | 获取待审核商品详情 | 🎭 SUPER_ADMIN / STAFF / HOSPITAL_ADMIN |
| POST | /admin/shop/pending-products/:id/review | 审核商品 | 🎭 SUPER_ADMIN / STAFF / HOSPITAL_ADMIN |

#### 获取待审核商品列表

```typescript
// GET /admin/shop/pending-products
{
  page?: number          // 页码，默认 1
  pageSize?: number      // 每页数量，默认 10，最大 100
  status?: string        // 审核状态：under_review（待审核）、approved（已通过）、rejected（已拒绝）
  keyword?: string       // 搜索关键词（商品标题、用户昵称、手机号）
  categoryId?: number    // 分类ID
}

// 响应
{
  data: [
    {
      "id": 1,
      "title": "皇家狗粮",
      "description": "高品质狗粮...",
      "price": 299.00,
      "stock": 3,
      "images": ["/uploads/..."],
      "categoryId": 11,
      "category": {
        "id": 11,
        "name": "宠物食品"
      },
      "condition": "90%",
      "negotiable": true,
      "shippingFee": 0,
      "status": "under_review",
      "rejectReason": null,
      "productId": null,
      "userId": 100,
      "user": {
        "id": 100,
        "nickname": "宠物爱好者",
        "phone": "138****1234"
      },
      "createdAt": "2026-02-09T10:00:00.000Z",
      "updatedAt": "2026-02-09T10:00:00.000Z"
    }
  ],
  total: 100,
  page: 1,
  limit: 10
}
```

#### 获取待审核商品详情

```typescript
// GET /admin/shop/pending-products/:id

// 响应
{
  "id": 1,
  "title": "皇家狗粮",
  "description": "高品质狗粮...",
  "price": 299.00,
  "stock": 3,
  "images": ["/uploads/..."],
  "categoryId": 11,
  "category": {
    "id": 11,
    "name": "宠物食品"
  },
  "condition": "90%",
  "negotiable": true,
  "shippingFee": 0,
  "status": "under_review",
  "rejectReason": null,
  "productId": null,
  "userId": 100,
  "user": {
    "id": 100,
    "nickname": "宠物爱好者",
    "phone": "13800138000"
  },
  "createdAt": "2026-02-09T10:00:00.000Z",
  "updatedAt": "2026-02-09T10:00:00.000Z"
}
```

#### 审核商品

```typescript
// POST /admin/shop/pending-products/:id/review
{
  approved: boolean        // true=通过，false=拒绝
  rejectReason?: string    // 拒绝原因（拒绝时必填，最多500字）
}

// 响应
{
  "success": true,
  "message": "审核通过" // 或 "审核拒绝"
}
```

**业务逻辑**：

- **审核通过**：
  1. 如果 `productId` 存在，更新对应的正式商品记录
  2. 如果 `productId` 不存在，创建新的正式商品记录
  3. 双向关联：更新 `pendingProduct.productId` 和 `formalProduct.pendingProductId`
  4. **库存同步规则**：待审核商品 `stock` 默认值为 `1`，最小值为 `1`；审核通过时会同步到正式商品 `stock`
  5. **默认 SKU 同步**：用户发布商品始终按单规格模型落库，自动创建或复用默认 SKU（名称：默认规格），并将其库存同步为待审核商品 `stock`
  6. 更新待审核商品状态为 `on_shelf`
  7. 向用户发送站内消息（跳转到商品详情）

- **审核拒绝**：
  1. 更新待审核商品状态为 `rejected`
  2. 记录拒绝原因到 `rejectReason` 字段
  3. 向用户发送站内消息（跳转到我的商品）

**错误处理**：

- `400 Bad Request` - 拒绝时未填写原因
- `400 Bad Request` - 商品已审核
- `404 Not Found` - 商品不存在

### SKU 接口

| HTTP 方法 | 路径                                  | 描述         | 权限 |
| --------- | ------------------------------------- | ------------ | ---- |
| GET       | /shop/products/:id/skus               | 获取商品 SKU | 🌐   |
| POST      | /shop/products/:id/skus               | 创建 SKU     | 🎭   |
| POST      | /shop/products/:id/skus/batch         | 批量创建 SKU | 🎭   |
| PUT       | /shop/products/:productId/skus/:skuId | 更新 SKU     | 🎭   |
| DELETE    | /shop/products/:productId/skus/:skuId | 删除 SKU     | 🎭   |

### 订单接口

| HTTP 方法 | 路径                     | 描述                | 权限                  |
| --------- | ------------------------ | ------------------- | --------------------- |
| GET       | /shop/orders                        | 后台订单列表              | 🎭 SUPER_ADMIN, STAFF |
| GET       | /shop/orders/my                     | 获取我的订单（兼容入口）  | 🎭 USER               |
| GET       | /shop/orders/purchases              | 我买到的                  | 🎭 USER               |
| GET       | /shop/orders/sales                  | 我卖出的                  | 🎭 USER               |
| GET       | /shop/orders/action-summary         | 买卖双方待处理数量        | 🎭 USER               |
| GET       | /shop/orders/:id                    | 获取角色化订单详情        | 🎭                    |
| POST      | /shop/orders                        | 创建订单                  | 🎭                    |
| POST      | /shop/orders/preview                | 订单试算/优惠券校验       | 🎭                    |
| PUT       | /shop/orders/:id/status             | 普通订单后台状态操作      | 🎭 SUPER_ADMIN, STAFF |
| POST      | /shop/orders/:id/cancel             | 取消待付款订单            | 🎭 USER               |
| POST      | /shop/orders/:id/pay                | 发起订单支付              | 🎭 USER, DOCTOR       |
| POST      | /shop/orders/:id/confirm-receipt    | 买家确认收货              | 🎭 USER               |
| POST      | /shop/orders/:id/ship               | 二手订单卖家确认发货      | 🎭 USER               |
| PATCH     | /shop/orders/:id/tracking           | 二手订单卖家修改物流单号  | 🎭 USER               |
| POST      | /shop/orders/:id/after-sales        | 买家申请商城订单售后      | 🎭 USER               |

#### 获取我的订单

**端点:** `GET /shop/orders/my`

**描述:** 获取当前用户的订单列表，支持分页和状态筛选。

**查询参数:**

| 参数     | 类型   | 必填 | 默认值 | 说明                                                 |
| -------- | ------ | ---- | ------ | ---------------------------------------------------- |
| page     | number | 否   | 1      | 页码                                                 |
| pageSize | number | 否   | 20     | 每页数量                                             |
| status   | string | 否   | -      | 订单状态（pending/paid/shipped/completed/cancelled） |
| orderType | string | 否 | - | 订单类型（normal/second_hand） |
| afterSaleStatus | string | 否 | - | 售后状态 |

**响应示例:**

```json
{
  "code": 0,
  "data": [
    {
      "id": 1,
      "orderNo": "ORD1234567890",
      "status": "pending",
      "totalAmount": "99.00",
      "originalAmount": "99.00",
      "couponDiscount": "0.00",
      "items": [
        {
          "productId": 1,
          "productName": "商品名称",
          "productImage": "/uploads/product.jpg",
          "quantity": 1,
          "price": "99.00",
          "skuId": 1,
          "skuName": "默认规格"
        }
      ],
      "shippingAddress": "收货地址",
      "receiverName": "收货人",
      "receiverPhone": "13800138000",
      "remark": "",
      "userId": 1,
      "createdAt": "2024-01-01T00:00:00.000Z",
      "paidAt": null,
      "shippedAt": null,
      "completedAt": null,
      "paymentMethod": null,
      "paymentNo": null,
      "cancelReason": null,
      "cancelledAt": null
    }
  ],
  "pagination": {
    "total": 100,
    "page": 1,
    "pageSize": 20,
    "totalPages": 5
  }
}
```

**重要说明:**

- **图片优先级**: `productImage` 字段优先使用商品图片数组（`images`）的第一张图片，如果数组为空则使用商品主图（`image`）
- **不使用 SKU 图片**: 订单项图片只使用商品级别的图片，不使用 SKU 级别的图片
- **图片自动填充**: 如果订单创建时商品没有图片，接口会自动查询商品表填充 `productImage` 字段
- **空图片处理**: 如果商品没有图片，`productImage` 为 `null`，前端应显示默认占位图

#### 创建订单

**端点:** `POST /shop/orders`

**描述:** 创建商城订单，并在同一链路中完成库存检查、优惠券锁定/核销、支付单创建。Flutter APP 会真实提交 `userCouponId`，默认不传测试态 `isVirtualPayment`。

**请求参数:**

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| items | Array<{ productId: number; skuId?: number; quantity: number }> | 是 | 下单商品列表 |
| shippingAddress | string | 是 | 完整收货地址 |
| receiverName | string | 是 | 收货人姓名 |
| receiverPhone | string | 是 | 收货人手机号 |
| remark | string | 否 | 订单备注 |
| userCouponId | number | 否 | 用户已领取优惠券 ID |
| paymentChannel | string | 是 | 支付渠道，见 `PaymentChannel` 枚举 |
| isVirtualPayment | boolean | 否 | 测试用虚拟支付开关 |

**请求示例:**

```json
{
  "items": [
    {
      "productId": 1001,
      "skuId": 2001,
      "quantity": 2
    }
  ],
  "shippingAddress": "上海市浦东新区测试路 1 号 1001 室",
  "receiverName": "张三",
  "receiverPhone": "13800000000",
  "remark": "工作日送达",
  "userCouponId": 5001,
  "paymentChannel": "alipay_wap",
  "isVirtualPayment": false
}
```

**成功响应示例:**

```json
{
  "order": {
    "id": 9001,
    "orderNo": "ORDTESTORDERNO0001",
    "status": "pending",
    "originalAmount": 199,
    "couponDiscount": 20,
    "totalAmount": 179,
    "items": [
      {
        "productId": 1001,
        "skuId": 2001,
        "productName": "处方粮",
        "skuName": "2kg",
        "quantity": 2,
        "price": 99.5
      }
    ],
    "shippingAddress": "上海市浦东新区测试路 1 号 1001 室",
    "receiverName": "张三",
    "receiverPhone": "13800000000",
    "remark": "工作日送达",
    "paymentMethod": "alipay",
    "paymentNo": "PAY202603120001"
  },
  "paymentParams": {
    "paymentNo": "PAY202603120001"
  }
}
```

**补充说明:**

- 二手订单只能包含一个用户发布商品，数量固定为 1，且只能有一个卖家。
- 二手商品禁止与平台商品混合下单，禁止买家购买自己发布的商品。
- 二手订单写入 `orderType=second_hand` 和商品发布者 `sellerId`，且不允许使用商城优惠券。
- 用户发布商品的货款不会在支付成功时进入卖家待审核余额，而是在买家确认收货或系统自动确认收货后才创建待审核结算记录。

**优惠券失败语义:**

| code                    | message 语义                 | 触发场景                                |
| ----------------------- | ---------------------------- | --------------------------------------- |
| `COUPON_NOT_FOUND`      | 优惠券不存在                 | `userCouponId` 不存在，或不属于当前用户 |
| `COUPON_NOT_APPLICABLE` | 优惠券已使用或失效           | 用户券状态不是 `AVAILABLE`              |
| `COUPON_NOT_APPLICABLE` | 优惠券已失效                 | 券规则状态不是 `ACTIVE`                 |
| `COUPON_NOT_APPLICABLE` | 优惠券已禁用                 | 券被后台禁用                            |
| `COUPON_NOT_APPLICABLE` | 优惠券尚未生效               | 当前时间早于券生效时间                  |
| `COUPON_NOT_APPLICABLE` | 优惠券已过期                 | 当前时间晚于券失效时间或用户券过期时间  |
| `COUPON_NOT_APPLICABLE` | 优惠券仅适用于指定商品       | 指定商品券与订单商品不匹配              |
| `COUPON_NOT_APPLICABLE` | 订单金额未达到优惠券使用门槛 | 满减/折扣门槛不满足                     |

**补充说明:**

- 服务端会在创建订单时复用与试算一致的优惠券适用性规则，不再接受“试算可用、下单不可用”的字段歧义
- 若支付单创建失败，订单回滚链路会返还已锁定/已核销优惠券

#### 订单试算 / 优惠券校验

**端点:** `POST /shop/orders/preview`

**描述:** 基于待下单商品计算订单金额，并返回当前用户在该订单上的优惠券可用性、优惠金额和不可用原因。适合 App 端做选券页与金额预览。

**请求参数:**

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| items | Array<{ productId: number; skuId?: number; quantity: number }> | 是 | 试算商品列表 |
| userCouponId | number | 否 | 当前选中的用户优惠券 ID，用于返回 `selectedCoupon` 与最终优惠金额 |

**请求示例:**

```json
{
  "items": [
    {
      "productId": 1001,
      "skuId": 2001,
      "quantity": 2
    }
  ],
  "userCouponId": 5001
}
```

**成功响应示例:**

```json
{
  "originalAmount": 199,
  "couponDiscount": 20,
  "totalAmount": 179,
  "containsUserPublishedProducts": true,
  "couponEligibleAmount": 149,
  "couponExcludedAmount": 50,
  "charityDonationRate": null,
  "charityDonationAmount": null,
  "selectedCoupon": {
    "id": 5001,
    "userId": 99,
    "couponId": 10,
    "status": "AVAILABLE",
    "validFrom": "2026-03-01T00:00:00.000Z",
    "validUntil": "2026-03-31T23:59:59.000Z",
    "expiresAt": "2026-03-31T23:59:59.000Z",
    "usedAt": null,
    "orderId": null,
    "createdAt": "2026-03-05T00:00:00.000Z",
    "coupon": {
      "id": 10,
      "name": "指定商品券",
      "type": "FULL_REDUCTION",
      "scope": "SPECIFIC",
      "description": "仅限指定商品使用",
      "status": "ACTIVE",
      "discountValue": 20,
      "minAmount": 100,
      "maxDiscount": null,
      "validFrom": "2026-03-01T00:00:00.000Z",
      "validUntil": "2026-03-31T23:59:59.000Z",
      "canStack": false,
      "isEnabled": true
    },
    "isApplicable": true,
    "discountAmount": 20
  },
  "coupons": [
    {
      "id": 5001,
      "userId": 99,
      "couponId": 10,
      "status": "AVAILABLE",
      "validFrom": "2026-03-01T00:00:00.000Z",
      "validUntil": "2026-03-31T23:59:59.000Z",
      "expiresAt": "2026-03-31T23:59:59.000Z",
      "usedAt": null,
      "orderId": null,
      "createdAt": "2026-03-05T00:00:00.000Z",
      "coupon": {
        "id": 10,
        "name": "指定商品券",
        "type": "FULL_REDUCTION",
        "scope": "SPECIFIC",
        "description": "仅限指定商品使用",
        "status": "ACTIVE",
        "discountValue": 20,
        "minAmount": 100,
        "maxDiscount": null,
        "validFrom": "2026-03-01T00:00:00.000Z",
        "validUntil": "2026-03-31T23:59:59.000Z",
        "canStack": false,
        "isEnabled": true
      },
      "isApplicable": true,
      "discountAmount": 20
    },
    {
      "id": 5002,
      "userId": 99,
      "couponId": 11,
      "status": "AVAILABLE",
      "validFrom": "2026-03-01T00:00:00.000Z",
      "validUntil": "2026-03-31T23:59:59.000Z",
      "expiresAt": "2026-03-31T23:59:59.000Z",
      "usedAt": null,
      "orderId": null,
      "createdAt": "2026-03-05T00:00:00.000Z",
      "coupon": {
        "id": 11,
        "name": "满 300 减 50",
        "type": "FULL_REDUCTION",
        "scope": "ALL",
        "description": "全场通用",
        "status": "ACTIVE",
        "discountValue": 50,
        "minAmount": 300,
        "maxDiscount": null,
        "validFrom": "2026-03-01T00:00:00.000Z",
        "validUntil": "2026-03-31T23:59:59.000Z",
        "canStack": false,
        "isEnabled": true
      },
      "isApplicable": false,
      "discountAmount": 0,
      "unavailableReason": "订单金额未达到优惠券使用门槛"
    }
  ]
}
```

**说明:**

- `selectedCoupon` 仅在请求中传入 `userCouponId` 时返回对应券信息；未传时为 `null`
- `coupons[].isApplicable` 表示当前订单是否可用
- `coupons[].discountAmount` 为该券对当前订单的实际优惠金额
- `coupons[].unavailableReason` 仅在 `isApplicable=false` 时返回，用于前端展示禁用原因
- `containsUserPublishedProducts=true` 表示当前试算是二手商品订单；二手商品不能与平台商品混合，且不可使用优惠券
- `couponEligibleAmount` 为参与优惠券门槛与优惠计算的系统商品金额
- `couponExcludedAmount` 为不参与优惠券计算的用户发布商品金额
- `charityDonationRate` 为当前启用的商城自动公益比例（百分比），例如 `1.5` 表示成交金额的 1.5% 将捐赠至流浪动物公益基金；二手商品订单、未配置有效公益活动或公益比例无效时返回 `null`
- `charityDonationAmount` 为本单预计捐赠金额，按订单最终实付金额（优惠券抵扣后）乘以 `charityDonationRate` 计算，并按分四舍五入；无有效公益比例时返回 `null`

#### 发起订单支付

**端点:** `POST /shop/orders/:id/pay`

**描述:** 对待支付订单重新发起支付。同一渠道重复点击会复用当前待支付尝试并重新生成支付参数；用户切换支付渠道时，服务端先关闭旧渠道的待支付尝试，再使用新的商户订单号创建当前渠道支付单。余额支付会在余额扣款事务中创建独立的 `success` 支付快照，订单始终绑定实际完成支付的 `paymentNo`。若创建订单时已经返回同支付方式的 `paymentParams`，Flutter App 可直接复用首单支付参数而不必再次调用本接口。

**请求参数:**

| 参数           | 类型   | 必填 | 说明                               |
| -------------- | ------ | ---- | ---------------------------------- |
| paymentChannel | string | 是   | 支付渠道，见 `PaymentChannel` 枚举 |

**请求示例:**

```json
{
  "paymentChannel": "alipay_wap"
}
```

**成功响应示例:**

```json
{
  "order": {
    "id": 9001,
    "orderNo": "ORDTESTORDERNO0001",
    "status": "pending",
    "totalAmount": 179
  },
  "paymentParams": {
    "paymentNo": "PAY202603120002"
  }
}
```

#### 确认收货

**端点:** `POST /shop/orders/:id/confirm-receipt`

**描述:** 买家确认已收到商品。仅已发货且没有进行中售后的订单可调用，成功后订单状态更新为 `completed`；二手订单随后幂等创建卖家待审核结算记录。

**请求示例:** 无请求体

**成功响应示例:**

```json
{
  "id": 9001,
  "orderNo": "ORDTESTORDERNO0001",
  "status": "completed",
  "completedAt": "2026-03-12T10:30:00.000Z"
}
```

#### 优惠券返还时序说明（2026-03-12 契约核对结果）

- 已确认会返券：用户主动取消待支付订单、支付关闭回调、支付失败回调、支付单创建失败后的回滚、30 分钟未支付自动取消任务
- 上述场景均复用统一取消链路 `cancelPendingOrderInternal() -> releaseOrderResources() -> releaseCouponForOrder()`，当前可视为稳定契约

#### 订单状态说明

| 状态      | 说明           |
| --------- | -------------- |
| pending   | 待支付         |
| paid      | 已支付，待发货 |
| shipped   | 已发货，待收货 |
| completed | 已完成         |
| cancelled | 已取消         |

#### 订单角色化响应

`GET /shop/orders/purchases`、`GET /shop/orders/sales` 和 `GET /shop/orders/:id` 会返回：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| viewRole | buyer \| seller | 当前用户在订单中的视角 |
| availableActions | string[] | 服务端计算的当前可用操作，APP 只按该字段显示按钮 |
| afterSaleSummary | object \| null | 最近一笔售后摘要 |
| autoConfirmAt | datetime \| null | 自动确认收货时间 |
| afterSaleDeadlineAt | datetime \| null | 已完成普通订单的售后截止时间 |
| trackingNumber | string \| null | 可选物流单号，不包含快递公司和物流轨迹 |

订单商品行包含稳定的 `lineKey`、优惠分摊 `discountAmount` 和实付金额 `paidAmount`。客户端必须使用 `lineKey` 申请售后，不得自行计算或提交退款金额。二手卖家首次发货使用 `POST /shop/orders/:id/ship`，请求体为 `{ "trackingNumber": "可选" }`。发货后可使用 `PATCH /shop/orders/:id/tracking` 补充、修改或清空物流单号；该操作不会修改原始 `shippedAt`。

`GET /shop/orders/:id` 额外返回 `charityDonationAmount: number | null`，表示本单商城自动公益入账减去退款冲销后的净额；没有商城公益流水时为 `null`。

#### 统一订单售后接口

| HTTP 方法 | 路径 | 描述 | 权限 |
| --- | --- | --- | --- |
| GET | /shop/after-sales/purchases | 买家售后列表 | 🎭 USER |
| GET | /shop/after-sales/sales | 卖家售后列表 | 🎭 USER |
| GET | /shop/after-sales/:id | 售后详情、商品行与操作日志 | 🎭 买家或二手卖家 |
| POST | /shop/after-sales/:id/cancel | 买家取消售后 | 🎭 买家 |
| POST | /shop/after-sales/:id/seller/approve | 卖家同意售后 | 🎭 卖家 |
| POST | /shop/after-sales/:id/seller/reject | 卖家拒绝售后 | 🎭 卖家 |
| POST | /shop/after-sales/:id/return | 买家提交退货信息 | 🎭 买家 |
| POST | /shop/after-sales/:id/confirm-return | 卖家确认收到退货 | 🎭 卖家 |
| POST | /shop/after-sales/:id/arbitration | 买家申请平台仲裁 | 🎭 买家 |

`handlerType=platform` 表示普通商城订单由平台直接处理，`handlerType=seller` 表示二手订单先由卖家处理。普通订单拒绝后直接关闭，不进入仲裁；二手订单拒绝或超时后可申请仲裁。

统一售后状态为 `pending_handler`、`handler_rejected`、`handler_timeout`、`waiting_buyer_return`、`waiting_handler_receipt`、`arbitration_pending`、`refunding`、`refunded`、`closed`。同一订单只能存在一个进行中售后，但结束后可按剩余可退款数量再次申请；有进行中售后时禁止手动或自动确认收货、后台强制完成及二手卖家结算。

创建售后请求体：

```json
{
  "afterSaleType": "refund_only",
  "items": [
    { "lineKey": "0c15b6b1-0fcc-4b4b-a146-3d83e225bdfa", "quantity": 1 }
  ],
  "reasonCode": "damaged",
  "description": "商品破损",
  "evidenceUrls": ["/uploads/evidence.jpg"]
}
```

`afterSaleType` 为 `refund_only` 或 `return_refund`。普通订单 `paid`、`shipped` 可申请，`completed` 仅能在 `afterSaleDeadlineAt` 前申请；发货前只允许 `refund_only`。退款金额由服务端按商品行实付、优惠分摊和剩余可退款数量计算。响应中的 `items` 会返回 `requestedQuantity`、`approvedQuantity`、`refundedQuantity`、`unitPrice`、`discountAmount`、`paidAmount`、`approvedAmount`、`refundedAmount`、`restockQuantity` 和 `inventoryRestoredQuantity`。

卖家同意请求体：

```json
{
  "returnRequired": true,
  "returnAddress": "退货地址；要求退货时必填",
  "reason": "处理说明"
}
```

卖家接口只允许处理 `handlerType=seller` 的二手售后。发货前同意售后会忽略 `returnRequired` 并直接退款。买家提交退货的 `trackingNumber` 和凭证图片均可选，不提供快递公司或物流轨迹查询。

#### Admin 售后管理接口

| HTTP 方法 | 路径 | 描述 | 权限 |
| --- | --- | --- | --- |
| GET | /shop/admin/after-sales | 售后管理列表 | 🎭 SUPER_ADMIN, STAFF |
| GET | /shop/admin/after-sales/:id | 售后管理详情 | 🎭 SUPER_ADMIN, STAFF |
| POST | /shop/admin/after-sales/:id/arbitrate | 提交仲裁结果 | 🎭 SUPER_ADMIN, STAFF |
| POST | /shop/admin/after-sales/:id/review | 审批或拒绝平台售后 | 🎭 SUPER_ADMIN, STAFF |
| POST | /shop/admin/after-sales/:id/confirm-return | 确认平台退货及回库数量 | 🎭 SUPER_ADMIN, STAFF |
| POST | /shop/admin/after-sales/:id/refund/retry | 重试失败退款 | 🎭 SUPER_ADMIN, STAFF |

列表支持 `page`、`pageSize`、`keyword`、`status`、`orderType`、`handlerType`、`productId`、`buyerId`、`overdue`、`view`、`createdFrom`、`createdTo`。`keyword` 同时匹配售后编号、订单号、买家及卖家的用户名/手机号；`view` 支持 `platform_pending`、`second_hand_arbitration`、`processing`、`finished`、`all`，并兼容旧值 `pending`。

平台审批请求体：

```json
{
  "decision": "approve",
  "afterSaleType": "return_refund",
  "approvedItems": [
    { "lineKey": "0c15b6b1-0fcc-4b4b-a146-3d83e225bdfa", "quantity": 1 }
  ],
  "reason": "审批说明（选填）",
  "returnAddress": "退货退款时必填"
}
```

拒绝时只需提交 `decision=reject`，`reason` 可选。无论审批通过还是拒绝，平台处理理由均不强制填写。Admin 只能选择服务端计算范围内的审批商品及数量，不能提交任意退款金额。

平台确认退货请求体：

```json
{
  "items": [
    { "lineKey": "0c15b6b1-0fcc-4b4b-a146-3d83e225bdfa", "restockQuantity": 1 }
  ],
  "remark": "包装完好，可重新销售"
}
```

仲裁请求体：

```json
{
  "decision": "support_buyer",
  "remark": "仲裁处理理由（选填）"
}
```

仲裁仅适用于二手售后，`remark` 可选。`decision` 为 `support_buyer` 时按服务端核定金额执行原支付渠道退款，为 `support_seller` 时关闭售后。任何商城订单都不能通过通用后台订单状态或通用退款接口绕过售后流程。

### 分类接口

| HTTP 方法 | 路径                      | 描述         | 权限                  |
| --------- | ------------------------- | ------------ | --------------------- |
| GET       | /shop/categories          | 获取分类列表 | 🌐                    |
| GET       | /shop/categories/:id      | 获取分类详情 | 🌐                    |
| GET       | /shop/categories/:id/path | 获取分类路径 | 🌐                    |
| POST      | /shop/categories          | 创建分类     | 🎭 SUPER_ADMIN, STAFF |
| PUT       | /shop/categories/:id      | 更新分类     | 🎭                    |
| PUT       | /shop/categories/:id/sort | 更新排序     | 🎭                    |
| DELETE    | /shop/categories/:id      | 删除分类     | 🎭                    |

**查询参数**:

```typescript
// GET /shop/categories
{
  status?: 'ACTIVE' | 'DISABLED'  // 状态筛选
  parentId?: number | null         // 父分类ID（null表示查询根分类）
  includeChildren?: boolean        // 是否包含子分类（返回树形结构）
  page?: number                    // 页码
  pageSize?: number                // 每页数量
}
```

### 优惠券接口

#### 用户端接口

| HTTP 方法 | 路径                          | 描述                         | 权限 |
| --------- | ----------------------------- | ---------------------------- | ---- |
| GET       | /shop/coupons/available       | 获取可领取优惠券             | ✅   |
| POST      | /shop/coupons/claim           | 领取优惠券                   | ✅   |
| GET       | /shop/coupons/scan/:claimCode | 根据扫码领取码获取优惠券详情 | ✅   |
| GET       | /shop/coupons/my              | 获取我的优惠券               | ✅   |
| GET       | /shop/coupons/my/count        | 获取我的优惠券数量统计       | ✅   |

**领取优惠券**

**端点:** `POST /shop/coupons/claim`

**描述:** 领取优惠券。现在支持两种入参：

- 传统领取：传 `couponId`
- 扫码领取：传 `claimCode`

**请求体:**

| 参数      | 类型   | 必填 | 说明                                                  |
| --------- | ------ | ---- | ----------------------------------------------------- |
| couponId  | number | 否   | 优惠券 ID。与 `claimCode` 二选一                      |
| claimCode | string | 否   | 扫码领取码，例如 `CLAIM_D37EBD`。与 `couponId` 二选一 |

**扫码领取请求示例:**

```json
{
  "claimCode": "CLAIM_D37EBD"
}
```

**成功响应示例:**

```json
{
  "id": 1002,
  "userId": 88,
  "couponId": 9,
  "status": "AVAILABLE",
  "expiredAt": "2026-03-31T23:59:59.000Z"
}
```

**根据扫码领取码获取优惠券详情**

**端点:** `GET /shop/coupons/scan/:claimCode`

**描述:** RN App 扫描二维码文本 `{"type":"coupons","value":"CLAIM_XXXXXX"}` 后，使用其中的 `value` 作为 `claimCode` 查询券详情与当前账号领取状态。

**路径参数:**

| 参数      | 类型   | 必填 | 说明                            |
| --------- | ------ | ---- | ------------------------------- |
| claimCode | string | 是   | 扫码领取码，例如 `CLAIM_D37EBD` |

**成功响应示例:**

```json
{
  "claimCode": "CLAIM_D37EBD",
  "claimType": "SCAN_CODE",
  "claimed": false,
  "canClaim": true,
  "unavailableReason": null,
  "coupon": {
    "id": 9,
    "name": "扫码立减券",
    "type": "FULL_REDUCTION",
    "scope": "ALL",
    "description": "扫码领取后可在商城使用",
    "status": "ACTIVE",
    "discountValue": 30,
    "minAmount": 199,
    "minOrderAmount": 199,
    "maxDiscount": null,
    "validFrom": "2026-03-01T00:00:00.000Z",
    "validUntil": "2026-03-31T23:59:59.000Z",
    "canStack": false,
    "isEnabled": true
  },
  "userCoupon": null
}
```

**字段说明:**

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| claimed | boolean | 当前账号是否已领取过该券 |
| canClaim | boolean | 当前账号是否还能领取 |
| unavailableReason | string \| null | 不可领取时的提示文案 |
| userCoupon | object \| null | 已领取时返回用户券信息，结构与 `GET /shop/coupons/my` 单项一致 |

**获取我的优惠券**

**端点:** `GET /shop/coupons/my`

**描述:** 获取当前用户已领取优惠券列表。RN App 当前直接消费该接口，并使用其中的 `validFrom`、`validUntil`、`expiresAt`、`coupon.discountValue`、`coupon.minAmount` 等字段做展示与选券。`coupon.minAmount` 为 app 侧统一使用门槛，服务端会取 `minAmount` 与 `minOrderAmount` 的较大值返回。

**查询参数:**

| 参数   | 类型                               | 必填 | 默认值 | 说明           |
| ------ | ---------------------------------- | ---- | ------ | -------------- |
| status | `AVAILABLE` \| `USED` \| `EXPIRED` | 否   | -      | 用户券状态筛选 |

**成功响应示例:**

```json
[
  {
    "id": 5001,
    "userId": 99,
    "couponId": 10,
    "status": "AVAILABLE",
    "validFrom": "2026-03-01T00:00:00.000Z",
    "validUntil": "2026-03-31T23:59:59.000Z",
    "expiresAt": "2026-03-31T23:59:59.000Z",
    "usedAt": null,
    "orderId": null,
    "createdAt": "2026-03-05T00:00:00.000Z",
    "coupon": {
      "id": 10,
      "name": "指定商品券",
      "type": "FULL_REDUCTION",
      "scope": "SPECIFIC",
      "description": "仅限指定商品使用",
      "status": "ACTIVE",
      "discountValue": 20,
      "minAmount": 100,
      "maxDiscount": null,
      "validFrom": "2026-03-01T00:00:00.000Z",
      "validUntil": "2026-03-31T23:59:59.000Z",
      "canStack": false,
      "isEnabled": true
    }
  }
]
```

**字段说明:**

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | number | 用户券 ID，创建订单时提交到 `userCouponId` |
| validFrom | string | 当前用户券可用开始时间 |
| validUntil | string | 当前用户券可用结束时间 |
| expiresAt | string | 与 `validUntil` 同口径保留字段，兼容旧客户端 |
| coupon.discountValue | number | 券面优惠值 |
| coupon.minAmount | number | app 侧统一使用门槛，取 `minAmount` 与 `minOrderAmount` 的较大值 |
| coupon.maxDiscount | number \| null | 折扣券最大优惠金额 |
| coupon.scope | string | 使用范围，`ALL` 或 `SPECIFIC` |
| coupon.validUntil | string | 券规则有效期结束时间 |
| coupon.isEnabled | boolean | `true` 表示券规则当前启用 |

**获取我的优惠券数量统计**

**端点:** `GET /shop/coupons/my/count`

**成功响应示例:**

```json
{
  "available": 3,
  "used": 1,
  "expired": 2
}
```

#### 管理端接口

| HTTP 方法 | 路径 | 描述 | 权限 |
| --- | --- | --- | --- |
| GET | /shop/coupons | 获取所有优惠券 | 🎭 SUPER_ADMIN, STAFF |
| GET | /shop/coupons/list | 获取优惠券列表（分页） | 🎭 SUPER_ADMIN, STAFF |
| GET | /shop/coupons/:id | 获取优惠券详情 | 🎭 SUPER_ADMIN, STAFF |
| GET | /shop/coupons/:id/qrcode | 获取优惠券二维码 | 🎭 SUPER_ADMIN, STAFF |
| POST | /shop/coupons | 创建优惠券 | 🎭 SUPER_ADMIN, STAFF |
| PUT | /shop/coupons/:id | 更新优惠券 | 🎭 SUPER_ADMIN, STAFF |
| PUT | /shop/coupons/:id/toggle-status | 切换优惠券状态（启用/禁用） | 🎭 SUPER_ADMIN, STAFF |
| POST | /shop/coupons/:id/revoke | 作废优惠券 | 🎭 SUPER_ADMIN, STAFF |

**获取优惠券列表（分页）**

**端点:** `GET /shop/coupons/list`

**描述:** 获取优惠券列表，支持分页和筛选，自动更新优惠券状态（已过期、已领完）

**查询参数:**

| 参数      | 类型   | 必填 | 默认值 | 说明                                                  |
| --------- | ------ | ---- | ------ | ----------------------------------------------------- |
| page      | number | 否   | 1      | 页码                                                  |
| limit     | number | 否   | 10     | 每页数量                                              |
| name      | string | 否   | -      | 优惠券名称（模糊搜索）                                |
| type      | string | 否   | -      | 优惠券类型（FULL_REDUCTION/DISCOUNT/DIRECT_DISCOUNT） |
| scope     | string | 否   | -      | 使用范围（ALL/SPECIFIC）                              |
| isEnabled | number | 否   | -      | 启用状态（0-启用，1-禁用）                            |

**响应示例:**

```json
{
  "data": [
    {
      "id": 1,
      "name": "新人专享券",
      "description": "欢迎新用户",
      "type": "FULL_REDUCTION",
      "minAmount": 100,
      "discountValue": 10,
      "maxDiscount": null,
      "stock": 1000,
      "claimedCount": 50,
      "perUserLimit": 1,
      "validFrom": "2024-01-01T00:00:00Z",
      "validAt": "2024-12-31T23:59:59Z",
      "scope": "ALL",
      "minOrderAmount": 0,
      "canStack": 0,
      "isEnabled": 0,
      "isExpired": 0,
      "isClaimedOut": 0,
      "couponStatus": "ACTIVE",
      "claimType": "NEW_USER",
      "claimCode": null,
      "createdAt": "2024-01-01T00:00:00Z",
      "updatedAt": "2024-01-01T00:00:00Z"
    }
  ],
  "page": 1,
  "limit": 10,
  "totalPages": 10
}
```

**获取优惠券详情**

**端点:** `GET /shop/coupons/:id`

**描述:** 获取优惠券详情，如果是指定商品优惠券，会返回关联的商品列表

**响应示例:**

```json
{
  "id": 1,
  "name": "指定商品券",
  "type": "DIRECT_DISCOUNT",
  "scope": "SPECIFIC",
  "discountValue": 5,
  "products": [
    { "id": 1, "name": "商品A" },
    { "id": 2, "name": "商品B" }
  ]
  // ... 其他字段
}
```

**创建/更新优惠券**

**端点:** `POST /shop/coupons` / `PUT /shop/coupons/:id`

**请求参数:**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
| --- | --- | --- | --- | --- |
| name | string | 是 | - | 优惠券名称 |
| description | string | 否 | - | 优惠券描述 |
| type | string | 是 | - | 优惠券类型（FULL_REDUCTION/DISCOUNT/DIRECT_DISCOUNT） |
| minAmount | number | 是 | - | 满减门槛（元）；同时参与统一使用门槛计算 |
| discountValue | number | 是 | - | 优惠值（满减为减免金额，折扣为折扣比例，直减为直减金额） |
| maxDiscount | number | 否 | - | 最大优惠金额（折扣券专用） |
| stock | number | 是 | - | 发放总量 |
| perUserLimit | number | 是 | 1 | 每人限领数量 |
| validFrom | string | 是 | - | 有效期开始时间（ISO 8601） |
| validAt | string | 是 | - | 有效期结束时间（ISO 8601） |
| scope | string | 否 | ALL | 使用范围（ALL/SPECIFIC） |
| productIds | number[] | 条件 | - | 指定商品 ID 列表（scope=SPECIFIC 时必填） |
| minOrderAmount | number | 否 | 0 | 最低订单金额限制（元）；实际生效门槛为 `max(minAmount, minOrderAmount)` |
| canStack | number | 否 | 0 | 是否可叠加使用（0-否，1-是） |
| isEnabled | number | 否 | 0 | 启用状态（0-启用，1-禁用） |
| claimType | string | 否 | - | 领取方式（NEW_USER-新用户领取，SCAN_CODE-扫码领取） |

**请求示例:**

```json
{
  "name": "新人专享券",
  "description": "欢迎新用户",
  "type": "FULL_REDUCTION",
  "minAmount": 100,
  "discountValue": 10,
  "stock": 1000,
  "perUserLimit": 1,
  "validFrom": "2024-01-01T00:00:00Z",
  "validAt": "2024-12-31T23:59:59Z",
  "scope": "SPECIFIC",
  "productIds": [1, 2, 3],
  "minOrderAmount": 0,
  "canStack": 0,
  "isEnabled": 0,
  "claimType": "SCAN_CODE"
}
```

**说明:**

- 当 `claimType` 设置为 `SCAN_CODE`（扫码领取）时：
  - **创建优惠券**：系统会自动生成唯一的领取码（格式：`CLAIM_XXXXXX`）
  - **更新优惠券**：如果原优惠券没有领取码，系统会自动生成一个；如果已有领取码，则保持不变
- 领取码生成后不可修改，确保二维码链接的稳定性

**切换优惠券状态**

**端点:** `PUT /shop/coupons/:id/toggle-status`

**描述:** 切换优惠券的启用/禁用状态。禁用后，已领取但未使用的优惠券将失效。

**响应:** 204 No Content

---

**获取优惠券二维码**

**端点:** `GET /shop/coupons/:id/qrcode`

**描述:** 获取扫码领取类型优惠券的二维码图片。

**路径参数:**

| 参数 | 类型   | 必填 | 说明      |
| ---- | ------ | ---- | --------- |
| id   | number | 是   | 优惠券 ID |

**成功响应示例:**

```json
{
  "success": true,
  "qrcode": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAA..."
}
```

**失败响应示例:**

```json
{
  "success": false,
  "message": "该优惠券不是扫码领取类型，无法生成二维码"
}
```

**说明:**

- 返回 PNG 格式的 base64 编码图片
- 图片宽度：300px
- 二维码内容：`{"type":"coupons","value":"CLAIM_XXXXXX"}`
- 其中 `CLAIM_XXXXXX` 是该优惠券的专属领取码
- App 扫码后应调用 `GET /shop/coupons/scan/:claimCode` 获取券详情，再根据 `canClaim` 决定是否调用 `POST /shop/coupons/claim`
- **如果优惠券是扫码领取类型但没有领取码，系统会自动生成一个并保存到数据库**
- 前端应根据 `success` 字段判断是否成功，失败时显示 `message` 中的错误信息

---

## Upload 模块

文件先在服务端临时目录中完成格式校验、图片处理或视频抽帧，再由服务端使用私有 COS 凭证上传到 `gdcw-1386217335`（`ap-chengdu`）。数据库及接口仍保存/返回 `/uploads/...` 相对路径，客户端不得把 API 域名直接作为资源域名。

| HTTP 方法 | 路径                  | 描述                             | 权限 |
| --------- | --------------------- | -------------------------------- | ---- |
| POST      | /upload/image         | 上传图片（自动压缩和生成缩略图） | ✅   |
| POST      | /upload/images/batch  | 批量上传图片（最多 9 张）        | ✅   |
| POST      | /upload/file          | 上传通用文件（含视频/音频/PDF）  | ✅   |
| GET       | /upload               | 获取文件列表                     | ✅   |
| GET       | /upload/:id           | 获取文件详情                     | ✅   |
| DELETE    | /upload/:id           | 删除文件                         | ✅   |
| GET       | /upload/stats/summary | 获取文件统计                     | ✅   |

### 上传图片

**端点:** `POST /upload/image`

**描述:** 上传单个图片，自动压缩和生成缩略图，处理完成后持久化到 COS 并清理服务端临时文件。仅支持真实内容为 JPG、PNG、GIF 或 WebP 的图片；HEIC/HEIF 不支持。

**请求方式:** multipart/form-data

**请求参数:**

| 参数              | 类型    | 必填 | 默认值 | 说明                 |
| ----------------- | ------- | ---- | ------ | -------------------- |
| file              | File    | 是   | -      | 图片文件             |
| category          | string  | 否   | -      | 文件分类（便于管理） |
| description       | string  | 否   | -      | 文件描述             |
| tags              | string  | 否   | -      | 文件标签（逗号分隔） |
| compress          | boolean | 否   | true   | 是否自动压缩图片     |
| generateThumbnail | boolean | 否   | true   | 是否生成缩略图       |

> `category` / `description` / `tags` / `compress` / `generateThumbnail` 同时支持 `multipart/form-data` 字段和 query 参数，query 优先级更高（兼容旧调用方式）。

> 服务端会读取文件头并验证图片是否可解析，不只信任扩展名或请求声明的 MIME。验证失败的临时文件会被删除；验证成功后，服务器文件名扩展名会按检测到的真实格式规范化。

**图片处理规则:**

- **压缩规则:**
  - 宽高限制: 1600px（等比缩放，不放大小图）
  - 输出格式: 保持原图格式（`jpg/jpeg`、`png`、`webp`），不会将 `png/webp` 写成 `jpg` 内容
  - 质量参数:
    - JPEG: `quality=72`（mozjpeg + progressive）
    - PNG: `quality=75` + `compressionLevel=9` + `palette=true`
    - WebP: `quality=72` + `alphaQuality=72`
  - 自动旋转（根据 EXIF）
  - 若压缩结果不比原图小，则保留原图
  - 动图（GIF/Animated WebP）自动跳过压缩，避免破坏动效

- **缩略图规则:**
  - 尺寸: 150x150 像素
  - 裁剪模式: 居中裁剪 (cover)
  - 质量: 60%

**响应示例:**

```json
{
  "url": "/uploads/abc123.jpg",
  "thumbnail": "/uploads/thumbnails/abc123_150x150.jpg",
  "filename": "abc123.jpg",
  "originalName": "photo.jpg",
  "size": 1524000,
  "width": 1920,
  "height": 1080,
  "id": 1
}
```

### 批量上传图片

**端点:** `POST /upload/images/batch`

**描述:** 批量上传最多 9 张图片，成功文件会持久化到 COS；仅支持真实内容为 JPG、PNG、GIF 或 WebP 的图片；HEIC/HEIF 不支持。

**请求方式:** multipart/form-data

**请求参数:**

| 参数              | 类型    | 必填 | 默认值 | 说明                      |
| ----------------- | ------- | ---- | ------ | ------------------------- |
| files             | File[]  | 是   | -      | 图片文件数组（最多 9 张） |
| category          | string  | 否   | -      | 文件分类                  |
| compress          | boolean | 否   | true   | 是否自动压缩              |
| generateThumbnail | boolean | 否   | true   | 是否生成缩略图            |

> `category` / `compress` / `generateThumbnail` 同时支持 `multipart/form-data` 字段和 query 参数，query 优先级更高（兼容旧调用方式）。

> 每个文件都会执行与单图上传相同的文件头和图片可解析性校验，并按检测到的真实格式规范化服务器文件名扩展名。

**响应示例:**

```json
{
  "total": 2,
  "successCount": 2,
  "failCount": 0,
  "results": [
    {
      "filename": "image1.jpg",
      "success": true,
      "data": {
        "url": "/uploads/abc1.jpg",
        "thumbnail": "/uploads/thumbnails/abc1_150x150.jpg",
        "width": 1920,
        "height": 1080,
        "size": 1524000,
        "id": 2
      }
    },
    {
      "filename": "image2.jpg",
      "success": true,
      "data": {
        "url": "/uploads/abc2.jpg",
        "thumbnail": "/uploads/thumbnails/abc2_150x150.jpg",
        "width": 1920,
        "height": 1080,
        "size": 1624000,
        "id": 3
      }
    }
  ]
}
```

### 上传文件

**端点:** `POST /upload/file`

**描述:** 上传通用文件，仅支持 PDF、视频和音频，不接受图片作为主文件。医生咨询视频消息和社区视频上传建议走该接口；当 APP 端已经本地抽帧时，可把 `thumbnail` 与 `file` 一起上传，服务端会优先保存客户端缩略图。MP4、M4V 和 MOV 视频默认在上传成功后进入后台压缩队列，上传接口无需等待转码完成。

**请求方式:** multipart/form-data

**请求参数:**

| 参数        | 类型   | 必填 | 说明                                          |
| ----------- | ------ | ---- | --------------------------------------------- |
| file        | File   | 是   | 文件本体，支持视频 `mp4/mov/...` 等           |
| thumbnail   | File   | 否   | 视频缩略图，推荐由 APP 端本地抽帧后与视频同传 |
| category    | string | 否   | 文件分类，聊天视频建议使用 `chat-video`       |
| description | string | 否   | 文件描述                                      |
| tags        | string | 否   | 文件标签（逗号分隔）                          |
| compress    | boolean | 否   | 是否自动压缩支持的视频，默认 `true`           |

> `category` / `description` / `tags` / `compress` 同时支持 `multipart/form-data` 字段和 query 参数，query 优先级更高。

**响应示例:**

```json
{
  "url": "/uploads/abc123.mp4",
  "filename": "abc123.mp4",
  "originalName": "consultation.mp4",
  "size": 12503456,
  "thumbnail": "/uploads/thumbnails/abc123_video_cover.jpg",
  "id": 12
}
```

> 说明：当上传的是视频文件时，若客户端传入 `thumbnail`，服务端会优先保存并返回该缩略图地址；若未传入，则服务端会尽力抽取一张缩略图并通过 `thumbnail` 返回。聊天视频消息和社区帖子都应把返回的 `thumbnail` 一并持久化，后续列表/消息预览直接使用该地址。

> 服务端会根据文件头校验主文件的真实类型，并按检测结果规范化服务器文件名扩展名。客户端上传的视频缩略图也必须是真实且可解析的 JPG、PNG、GIF 或 WebP 图片；校验失败时主文件和缩略图都会被清理。

> 视频原文件会先上传到 COS，再在 Bull/Redis 后台队列中单并发压缩。当前输出目标为 H.264 + AAC、最大边 1280 像素、最高 30fps、`yuv420p`，并启用 MP4/MOV `faststart`。只有压缩结果比原文件小时才会覆盖同一个 COS 对象 Key，并更新文件记录的 `size` 和 `isCompressed`；压缩失败或无体积收益时 COS 保留原文件。因此响应中的 `url` 始终不变，`size` 是上传接口返回时的原始文件大小。

### 支持的文件类型

- 图片: `image/jpeg`, `image/png`, `image/gif`, `image/webp`
- 文档: `application/pdf`
- 视频: MP4/M4V、MOV、MPEG、AVI、WMV、WebM
- 音频: MP3、M4A、AAC、AMR、OGG、WAV、WebM

`/upload/image` 和 `/upload/images/batch` 只接受上述图片；`/upload/file` 只接受上述文档、视频和音频。HEIC/HEIF 当前不支持。

**文件大小限制:** 100MB（NestJS `MAX_FILE_SIZE` 与 Nginx `client_max_body_size` 均需保持一致）

---

## Audit 模块

审计日志

| HTTP 方法 | 路径                           | 描述             | 权限 |
| --------- | ------------------------------ | ---------------- | ---- |
| GET       | /audit/logs                    | 查询审计日志     | ✅   |
| GET       | /audit/logs/user/:targetUserId | 查询指定用户日志 | ✅   |
| GET       | /audit/logs/action/:action     | 查询指定操作日志 | ✅   |

---

## SMS 模块

短信服务

| HTTP 方法 | 路径           | 描述         | 权限                           |
| --------- | -------------- | ------------ | ------------------------------ |
| POST      | /sms/send-code | 发送验证码   | 🌐                             |
| GET       | /sms/records   | 获取短信记录 | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN |
| GET       | /sms/stats     | 获取短信统计 | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN |

---

## Payment 模块

支付管理

| HTTP 方法 | 路径                      | 描述         | 权限                  |
| --------- | ------------------------- | ------------ | --------------------- |
| POST      | /payment/create           | 创建支付     | ✅                    |
| GET       | /payment/query/:paymentNo | 查询本人支付状态；管理员可诊断查询 | ✅                    |
| POST      | /payment/close/:paymentNo | 关闭支付     | 🎭 SUPER_ADMIN, STAFF |
| POST      | /payment/refund           | 非商城业务管理员诊断退款 | 🎭 SUPER_ADMIN, STAFF |
| GET       | /payment/list             | 查询支付列表 | 🎭 SUPER_ADMIN, STAFF |
| POST      | /payment/callback/alipay  | 支付宝回调   | 🌐                    |
| POST      | /payment/callback/wechat  | 微信回调     | 🌐                    |
| GET       | /payment/my               | 我的支付记录 | ✅                    |

`GET /payment/query/:paymentNo` 会校验支付单归属，普通用户只能查询自己的支付单，并返回专用状态 DTO，不返回 `Payment` 实体或内部主键。商城订单在支付完成前可以切换渠道：旧渠道待支付单会关闭并保留审计记录，新渠道使用新的商户订单号；已关闭支付单的迟到回调不能推进订单。公益支付宝捐款使用 `charity_donation` 业务类型，支付成功后会在支付事务内幂等生成公益捐款记录。`POST /payment/refund` 不接受普通用户调用；即使是管理员也不能用该接口退款 `shop_order`，商城退款必须由处于 `refunding` 状态的有效售后单通过服务端内部入口触发，金额不可由客户端指定。售后退款优先匹配订单当前 `paymentNo`；历史余额订单仅在订单支付快照与已审核钱包扣款流水金额一致时补建余额支付记录。

### 支付宝异步通知回执

`POST /payment/callback/alipay` 接收支付宝发送的
`application/x-www-form-urlencoded` 异步通知。该接口使用支付宝要求的纯文本回执，
不会经过服务端统一 JSON 响应包装。

服务端使用支付宝原始字段验签，并校验 `app_id`、`out_trade_no`、`trade_no`、
`total_amount` 和 `trade_status`；回调金额必须与本地支付单金额一致。支付成功后，
支付单、支付流水和对应业务记录在同一事务内更新，重复通知不会重复写入流水或公益捐款记录，且会补偿历史上
“支付单已成功、业务记录仍未完成”的状态。

| 处理结果 | HTTP 状态码 | Content-Type | 响应体    |
| -------- | ----------- | ------------ | --------- |
| 成功     | 200         | text/plain   | `success` |
| 失败     | 200         | text/plain   | `failure` |

### Apple Universal Link 关联资源

支付宝 iOS 回跳使用以下公开资源。该地址由 HTTPS Nginx 直接返回，不经过应用服务，也不能发生二次重定向。

| HTTP 方法 | 路径                                        | 描述                  | 权限 |
| --------- | ------------------------------------------- | --------------------- | ---- |
| GET       | /.well-known/apple-app-site-association     | Apple AASA 关联文件   | 🌐   |

生产地址：`https://gudeapi.zuoyongyoubao.com/.well-known/apple-app-site-association`

响应头：`Content-Type: application/json`

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "RK2294UDR8.com.gude.cwyy",
        "paths": ["/alipay/*"]
      }
    ]
  }
}
```

---

## Health Articles 模块

健康知识文章管理

### 文章管理接口

| HTTP 方法 | 路径                           | 描述                             | 权限           |
| --------- | ------------------------------ | -------------------------------- | -------------- |
| POST      | /health-articles               | 创建文章                         | 🎭 SUPER_ADMIN |
| PUT       | /health-articles/:id           | 更新文章                         | 🎭 SUPER_ADMIN |
| DELETE    | /health-articles/:id           | 删除文章（软删除）               | 🎭 SUPER_ADMIN |
| PATCH     | /health-articles/:id/publish   | 发布文章                         | 🎭 SUPER_ADMIN |
| PATCH     | /health-articles/:id/unpublish | 取消发布文章                     | 🎭 SUPER_ADMIN |
| GET       | /health-articles               | 获取文章列表（分页、筛选、排序） | 🌐             |
| GET       | /health-articles/:id           | 获取文章详情（阅读量+1）         | 🌐             |

### 文章互动接口

| HTTP 方法 | 路径                          | 描述             | 权限    |
| --------- | ----------------------------- | ---------------- | ------- |
| POST      | /health-articles/:id/favorite | 收藏文章         | ✅ USER |
| DELETE    | /health-articles/:id/favorite | 取消收藏文章     | ✅ USER |
| GET       | /health-articles/favorites/me | 获取我的收藏列表 | ✅ USER |
| POST      | /health-articles/:id/like     | 点赞文章         | ✅ USER |
| DELETE    | /health-articles/:id/like     | 取消点赞文章     | ✅ USER |

### 分类管理接口

| HTTP 方法 | 路径                            | 描述         | 权限           |
| --------- | ------------------------------- | ------------ | -------------- |
| POST      | /health-articles/categories     | 创建分类     | 🎭 SUPER_ADMIN |
| PUT       | /health-articles/categories/:id | 更新分类     | 🎭 SUPER_ADMIN |
| DELETE    | /health-articles/categories/:id | 删除分类     | 🎭 SUPER_ADMIN |
| GET       | /health-articles/categories     | 获取分类列表 | 🌐             |
| GET       | /health-articles/categories/:id | 获取分类详情 | 🌐             |

### 数据结构

```typescript
// 文章状态
enum ArticleStatus {
  DRAFT = 'DRAFT', // 草稿
  PUBLISHED = 'PUBLISHED' // 已发布
}

// 健康文章
interface HealthArticle {
  id: number
  title: string
  summary: string
  content: string
  coverImage?: string
  categoryId: number
  category?: HealthCategory
  status: ArticleStatus
  isPublished: boolean
  publishedAt?: string
  viewCount: number
  favoriteCount: number
  likeCount: number
  shareCount: number
  seoKeywords?: string
  seoDescription?: string
  authorId: number
  favorited?: boolean
  liked?: boolean
  createdAt: string
  updatedAt: string
}

// 健康分类
interface HealthCategory {
  id: number
  name: string
  slug: string
  icon?: string
  description?: string
  sortOrder: number
  isActive: boolean
  articleCount: number
  createdAt: string
  updatedAt: string
}
```

### 请求示例

```typescript
// 创建文章
POST /health-articles
{
  "title": "宠物疫苗接种指南",
  "summary": "详细介绍宠物疫苗接种的注意事项",
  "content": "<p>文章内容...</p>",
  "coverImage": "/uploads/article-cover.jpg",
  "categoryId": 1,
  "status": "DRAFT"
}

// 创建分类
POST /health-articles/categories
{
  "name": "犬类护理",
  "slug": "dog-care",
  "sortOrder": 1
}

// 收藏文章
POST /health-articles/1/favorite

// 发布文章
PATCH /health-articles/1/publish
```

---

## 通用说明

### 认证方式

大部分接口需要在请求头中携带 JWT Token：

```typescript
headers: {
  'Authorization': 'Bearer YOUR_TOKEN_HERE'
}
```

### 统一响应格式

成功响应：

```json
{
  "success": true,
  "statusCode": 200,
  "data": {...},
  "meta": {
    "timestamp": "2024-01-19T10:00:00.000Z"
  }
}
```

错误响应：

```json
{
  "success": false,
  "statusCode": 400,
  "error": {
    "code": "USER_NOT_FOUND",
    "message": "用户不存在"
  },
  "meta": {
    "timestamp": "2024-01-19T10:00:00.000Z"
  }
}
```

### 分页参数

```typescript
{
  page: 1,          // 页码
  pageSize: 10,     // 每页数量
  // ... 其他筛选条件
}
```

### 错误码

| 错误码 | 说明           |
| ------ | -------------- |
| 1xxx   | 认证相关错误   |
| 2xxx   | 资源不存在错误 |
| 3xxx   | 业务逻辑错误   |
| 4xxx   | 文件处理错误   |
| 5xxx   | 系统错误       |

---

## Swagger 文档

访问 `http://localhost:3000/api-docs` 查看完整的 Swagger API 文档。若从其他设备访问，请将 `localhost` 替换为当前电脑的局域网 IP、域名或代理地址。若 admin 端通过 `/server-api` 代理访问后端，则只需要调整代理目标，无需在业务代码中批量改写接口路径。

---

## AI Self Check 模块

AI 自查表管理相关接口，支持管理员创建公共项和特定项自查表，用户端可根据宠物 ID 查询对应的自查表。

**数据类型：**

```typescript
// 自查表类型
type SelfCheckListType = 'PUBLIC' | 'SPECIFIC' // 公共项 | 特定项

// 自查表状态
type SelfCheckListStatus = 'ACTIVE' | 'INACTIVE' // 启用 | 禁用

// 问题类型
type QuestionType = 'SINGLE' | 'MULTIPLE' | 'TEXT' // 单选 | 多选 | 填空

// 自查表
interface SelfCheckList {
  id: number
  title: string // 自查表标题
  type: SelfCheckListType // 类型
  categoryId: number | null // 关联的分类ID（特定项）
  categoryName?: string // 分类名称
  status: SelfCheckListStatus // 状态
  sortOrder: number // 排序序号
  questionCount?: number // 问题数量
  createdAt: string
  updatedAt: string
}

// 问题
interface SelfCheckQuestion {
  id: number
  listId: number // 所属自查表ID
  questionText: string // 问题描述
  questionType: QuestionType // 问题类型
  required: boolean // 是否必填
  sortOrder: number // 排序序号
  options?: SelfCheckOption[] // 选项列表
}

// 选项
interface SelfCheckOption {
  id: number
  questionId: number // 所属问题ID
  optionText: string // 选项描述
  optionImage: string | null // 选项表现图片URL
  sortOrder: number // 排序序号
}
```

### 自查表管理

#### 获取自查表列表

**接口：** `GET /ai-self-check/lists`

**权限：** ✅ 需要登录

**查询参数：**

| 参数       | 类型               | 必填 | 说明                |
| ---------- | ------------------ | ---- | ------------------- |
| type       | PUBLIC \| SPECIFIC | 否   | 类型筛选            |
| categoryId | number             | 否   | 分类 ID 筛选        |
| status     | ACTIVE \| INACTIVE | 否   | 状态筛选            |
| keyword    | string             | 否   | 关键词搜索（标题）  |
| page       | number             | 否   | 页码（默认 1）      |
| pageSize   | number             | 否   | 每页数量（默认 10） |

**响应示例：**

```json
{
  "code": 0,
  "data": [
    {
      "id": 1,
      "title": "宠物日常健康自查",
      "type": "PUBLIC",
      "categoryId": null,
      "status": "ACTIVE",
      "sortOrder": 0,
      "questionCount": 5,
      "createdAt": "2024-01-24T10:00:00.000Z",
      "updatedAt": "2024-01-24T10:00:00.000Z"
    }
  ],
  "pagination": {
    "total": 1,
    "page": 1,
    "pageSize": 10,
    "totalPages": 1
  },
  "message": "Success"
}
```

#### 获取自查表详情

**接口：** `GET /ai-self-check/lists/:id`

**权限：** ✅ 需要登录

**路径参数：**

| 参数 | 类型   | 必填 | 说明      |
| ---- | ------ | ---- | --------- |
| id   | number | 是   | 自查表 ID |

**响应示例：**

```json
{
  "code": 0,
  "data": {
    "id": 1,
    "title": "宠物日常健康自查",
    "type": "PUBLIC",
    "categoryId": null,
    "status": "ACTIVE",
    "sortOrder": 0,
    "questions": [
      {
        "id": 1,
        "listId": 1,
        "questionText": "宠物的食欲是否正常？",
        "questionType": "SINGLE",
        "required": true,
        "sortOrder": 0,
        "options": [
          {
            "id": 1,
            "questionId": 1,
            "optionText": "正常",
            "optionImage": null,
            "sortOrder": 0
          },
          {
            "id": 2,
            "questionId": 1,
            "optionText": "食欲不振",
            "optionImage": null,
            "sortOrder": 1
          }
        ]
      }
    ]
  },
  "message": "Success"
}
```

#### 创建自查表

**接口：** `POST /ai-self-check/lists`

**权限：** ✅ 需要登录 🎭 管理员

**请求体：**

```json
{
  "title": "宠物日常健康自查",
  "type": "PUBLIC",
  "categoryId": null,
  "status": "ACTIVE",
  "sortOrder": 0
}
```

**业务规则：**

- 特定项（SPECIFIC）必须选择分类（categoryId）
- 公共项（PUBLIC）不能选择分类

#### 更新自查表

**接口：** `PUT /ai-self-check/lists/:id`

**权限：** ✅ 需要登录 🎭 管理员

**路径参数：**

| 参数 | 类型   | 必填 | 说明      |
| ---- | ------ | ---- | --------- |
| id   | number | 是   | 自查表 ID |

**请求体：**（所有字段可选）

```json
{
  "title": "宠物日常健康自查（更新）",
  "categoryId": 1,
  "status": "INACTIVE",
  "sortOrder": 1
}
```

**注意：** 类型（type）字段不允许修改

#### 更新自查表状态

**接口：** `POST /ai-self-check/lists/:id/status`

**权限：** ✅ 需要登录 🎭 管理员

**路径参数：**

| 参数 | 类型   | 必填 | 说明      |
| ---- | ------ | ---- | --------- |
| id   | number | 是   | 自查表 ID |

**请求体：**

```json
{
  "status": "INACTIVE"
}
```

#### 删除自查表

**接口：** `DELETE /ai-self-check/lists/:id`

**权限：** ✅ 需要登录 🎭 管理员

**路径参数：**

| 参数 | 类型   | 必填 | 说明      |
| ---- | ------ | ---- | --------- |
| id   | number | 是   | 自查表 ID |

**响应示例：**

```json
{
  "code": 0,
  "data": {
    "success": true
  },
  "message": "Success"
}
```

### 问题管理

#### 获取问题列表

**接口：** `GET /ai-self-check/questions`

**权限：** ✅ 需要登录

**查询参数：**

| 参数   | 类型   | 必填 | 说明      |
| ------ | ------ | ---- | --------- |
| listId | number | 是   | 自查表 ID |

**响应示例：**

```json
{
  "code": 0,
  "data": [
    {
      "id": 1,
      "listId": 1,
      "questionText": "宠物的食欲是否正常？",
      "questionType": "SINGLE",
      "required": true,
      "sortOrder": 0,
      "options": [
        {
          "id": 1,
          "questionId": 1,
          "optionText": "正常",
          "optionImage": null,
          "sortOrder": 0
        }
      ]
    }
  ],
  "message": "Success"
}
```

#### 创建问题

**接口：** `POST /ai-self-check/questions`

**权限：** ✅ 需要登录 🎭 管理员

**请求体：**

```json
{
  "listId": 1,
  "questionText": "宠物的食欲是否正常？",
  "questionType": "SINGLE",
  "required": true,
  "sortOrder": 0,
  "options": [
    {
      "optionText": "正常",
      "optionImage": null,
      "sortOrder": 0
    },
    {
      "optionText": "食欲不振",
      "optionImage": null,
      "sortOrder": 1
    }
  ]
}
```

**业务规则：**

- 选择题（SINGLE、MULTIPLE）必须包含至少一个选项
- 填空题（TEXT）不能包含选项

#### 更新问题

**接口：** `PUT /ai-self-check/questions/:id`

**权限：** ✅ 需要登录 🎭 管理员

**路径参数：**

| 参数 | 类型   | 必填 | 说明    |
| ---- | ------ | ---- | ------- |
| id   | number | 是   | 问题 ID |

**请求体：**（所有字段可选）

```json
{
  "questionText": "宠物的食欲是否正常？（更新）",
  "questionType": "MULTIPLE",
  "required": false,
  "sortOrder": 1,
  "options": [
    {
      "optionText": "正常",
      "optionImage": null,
      "sortOrder": 0
    },
    {
      "optionText": "食欲不振",
      "optionImage": null,
      "sortOrder": 1
    },
    {
      "optionText": "食欲亢进",
      "optionImage": null,
      "sortOrder": 2
    }
  ]
}
```

**注意：**

- 修改问题类型为 TEXT 时，会自动删除所有选项
- 修改选项时会完全替换原有选项

#### 删除问题

**接口：** `DELETE /ai-self-check/questions/:id`

**权限：** ✅ 需要登录 🎭 管理员

**路径参数：**

| 参数 | 类型   | 必填 | 说明    |
| ---- | ------ | ---- | ------- |
| id   | number | 是   | 问题 ID |

#### 批量更新自查表排序

**接口：** `PATCH /ai-self-check/lists/reorder`

**权限：** ✅ 需要登录 🎭 管理员

**请求参数：**

| 参数    | 类型     | 必填 | 说明                                          |
| ------- | -------- | ---- | --------------------------------------------- |
| listIds | number[] | 是   | 按新顺序排列的自查表 ID 数组，如 [5, 2, 8, 1] |

**功能说明：**

- 批量更新多个自查表的排序
- 按数组顺序重新分配 sortOrder（从 0 开始）
- 使用事务保证数据一致性

**响应示例：**

```json
{
  "code": 0,
  "data": null,
  "message": "排序更新成功"
}
```

#### 批量更新问题排序

**接口：** `PATCH /ai-self-check/questions/reorder`

**权限：** ✅ 需要登录 🎭 管理员

**请求参数：**

| 参数        | 类型     | 必填 | 说明                       |
| ----------- | -------- | ---- | -------------------------- |
| questionIds | number[] | 是   | 按新顺序排列的问题 ID 数组 |

**功能说明：**

- 批量更新多个问题的排序
- 按数组顺序重新分配 sortOrder（从 0 开始）
- 使用事务保证数据一致性

**响应示例：**

```json
{
  "code": 0,
  "data": null,
  "message": "排序更新成功"
}
```

#### 批量更新选项排序

**接口：** `PATCH /ai-self-check/questions/:questionId/options/reorder`

**权限：** ✅ 需要登录 🎭 管理员

**路径参数：**

| 参数       | 类型   | 必填 | 说明    |
| ---------- | ------ | ---- | ------- |
| questionId | number | 是   | 问题 ID |

**请求参数：**

| 参数      | 类型     | 必填 | 说明                       |
| --------- | -------- | ---- | -------------------------- |
| optionIds | number[] | 是   | 按新顺序排列的选项 ID 数组 |

**功能说明：**

- 批量更新单个问题的多个选项排序
- 按数组顺序重新分配 sortOrder（从 0 开始）
- 使用事务保证数据一致性

**响应示例：**

```json
{
  "code": 0,
  "data": null,
  "message": "排序更新成功"
}
```

### 用户端查询

#### 根据宠物 ID 获取自查表列表

**接口：** `GET /ai-self-check/lists/by-pet/:petId`

**权限：** ✅ 需要登录

**路径参数：**

| 参数  | 类型   | 必填 | 说明    |
| ----- | ------ | ---- | ------- |
| petId | number | 是   | 宠物 ID |

**功能说明：**

- 自动返回所有公共项自查表
- 根据宠物的一级分类返回匹配的特定项自查表
- 结果按类型排序：公共项在前，特定项在后
- 同类型按 sortOrder 升序排列

**响应示例：**

```json
{
  "code": 0,
  "data": [
    {
      "id": 1,
      "title": "宠物日常健康自查",
      "type": "PUBLIC",
      "categoryId": null,
      "status": "ACTIVE",
      "sortOrder": 0,
      "questions": [
        {
          "id": 1,
          "questionText": "宠物的食欲是否正常？",
          "questionType": "SINGLE",
          "required": true,
          "sortOrder": 0,
          "options": [...]
        }
      ]
    },
    {
      "id": 2,
      "title": "狗狗常见问题自查",
      "type": "SPECIFIC",
      "categoryId": 1,
      "categoryName": "狗",
      "status": "ACTIVE",
      "sortOrder": 0,
      "questions": [...]
    }
  ],
  "message": "Success"
}
```

---

## AI Diagnosis Reports 模块

AI 问诊报告管理 - 替代旧的 AI Consultation 模块，使用 Bull Queue 实现异步诊断

### 获取 AI 问诊报告列表

- **接口**: `GET /ai-diagnosis-reports`
- **权限**: ✅ SUPER_ADMIN, DOCTOR, USER
- **功能**: 分页查询 AI 问诊报告列表，支持多维度筛选

**查询参数：**

| 参数      | 类型   | 必填 | 说明                                              |
| --------- | ------ | ---- | ------------------------------------------------- |
| page      | number | 否   | 页码，默认 1                                      |
| pageSize  | number | 否   | 每页大小，默认 10                                 |
| id        | number | 否   | 报告 ID 精确搜索                                  |
| userId    | number | 否   | 用户 ID（管理员/医生可筛选）                      |
| userPhone | string | 否   | 用户手机号模糊搜索                                |
| petId     | number | 否   | 宠物 ID                                           |
| status    | string | 否   | 状态：PENDING/PROCESSING/COMPLETED/FAILED/TIMEOUT |
| keyword   | string | 否   | 关键词搜索（症状描述）                            |
| startDate | string | 否   | 开始日期（YYYY-MM-DD）                            |
| endDate   | string | 否   | 结束日期（YYYY-MM-DD）                            |

**响应示例：**

```json
{
  "code": 0,
  "data": [
    {
      "id": 1,
      "userId": 10,
      "petId": 5,
      "petName": "旺财",
      "userPhone": "13800138000",
      "status": "COMPLETED",
      "createdAt": "2026-01-25 12:00:00",
      "completedAt": "2026-01-25 12:05:23",
      "updatedAt": "2026-01-25 12:05:23"
    }
  ],
  "pagination": {
    "total": 100,
    "page": 1,
    "pageSize": 10,
    "totalPages": 10
  },
  "message": "Success"
}
```

**字段说明：**

| 字段        | 类型   | 说明                                                   |
| ----------- | ------ | ------------------------------------------------------ |
| id          | number | 报告 ID                                                |
| userId      | number | 用户 ID                                                |
| petId       | number | 宠物 ID                                                |
| petName     | string | 宠物名称                                               |
| userPhone   | string | 用户手机号                                             |
| status      | string | 状态：PENDING/PROCESSING/COMPLETED/FAILED/TIMEOUT      |
| createdAt   | string | 创建时间（格式：YYYY-MM-DD HH:mm:ss）                  |
| completedAt | string | 完成时间（格式：YYYY-MM-DD HH:mm:ss，未完成时为 null） |
| updatedAt   | string | 更新时间（格式：YYYY-MM-DD HH:mm:ss）                  |

### 获取 AI 问诊报告详情

- **接口**: `GET /ai-diagnosis-reports/:id`
- **权限**: ✅ SUPER_ADMIN, DOCTOR, USER
- **功能**: 获取报告完整详情，包括西医和中医诊断结果

**路径参数：**

| 参数 | 类型   | 必填 | 说明    |
| ---- | ------ | ---- | ------- |
| id   | number | 是   | 报告 ID |

**响应示例：**

```json
{
  "code": 0,
  "data": {
    "id": 1,
    "userId": 10,
    "userName": "张三",
    "userPhone": "13800138000",
    "petId": 5,
    "petName": "旺财",
    "status": "COMPLETED",
    "symptoms": "宠物信息：旺财，狗，金毛，1岁3个月；生理指标：体温39.5°C，心率120次/分钟，呼吸频率30次/分钟；自查症状：是否呕吐？：是；症状描述：狗狗最近两天不吃东西，精神萎靡",
    "selfCheckSnapshot": [...],
    "westernDiagnosis": {
      "diagnosis": [
        {
          "symptom": "食欲不振",
          "reason": "可能是消化不良或肠胃疾病",
          "probability": 0.85
        }
      ],
      "medications": [...]
    },
    "tcmDiagnosis": {
      "data": [
        {
          "zhengming": "脾胃虚弱",
          "description": "脾胃运化功能失常",
          "p": 0.78,
          "therapy": "健脾益气",
          "base": "四君子汤",
          "continue": "加陈皮、半夏",
          "suggest": "注意饮食调理",
          "base_prescription": "四君子汤加减",
          "base_prescription_usage": "水煎服，每日一剂"
        }
      ]
    },
    "errorMessage": null,
    "createdAt": "2026-01-25 12:00:00",
    "updatedAt": "2026-01-25 12:05:23",
    "completedAt": "2026-01-25 12:05:23",
    "retryCount": 0
  },
  "message": "Success"
}
```

**字段说明：**

| 字段              | 类型   | 说明                                                   |
| ----------------- | ------ | ------------------------------------------------------ |
| id                | number | 报告 ID                                                |
| userId            | number | 用户 ID                                                |
| userName          | string | 用户名称                                               |
| userPhone         | string | 用户手机号                                             |
| petId             | number | 宠物 ID                                                |
| petName           | string | 宠物名称                                               |
| status            | string | 状态：PENDING/PROCESSING/COMPLETED/FAILED/TIMEOUT      |
| symptoms          | string | 完整诊断描述（宠物信息、疫苗/驱虫、生理指标、自查症状、用户主诉拼接而成） |
| selfCheckSnapshot | array  | 自查表快照                                             |
| westernDiagnosis  | object | 西医诊断结果                                           |
| tcmDiagnosis      | object | 中医诊断结果                                           |
| errorMessage      | string | 错误信息（失败时）                                     |
| createdAt         | string | 创建时间（格式：YYYY-MM-DD HH:mm:ss）                  |
| updatedAt         | string | 更新时间（格式：YYYY-MM-DD HH:mm:ss）                  |
| completedAt       | string | 完成时间（格式：YYYY-MM-DD HH:mm:ss，未完成时为 null） |
| retryCount        | number | 重试次数                                               |

### 创建 AI 问诊报告

- **接口**: `POST /ai-diagnosis-reports`
- **权限**: ✅ USER
- **功能**: 创建新的 AI 问诊报告，自动触发西医和中医诊断队列

服务端会将宠物信息、疫苗/驱虫情况、基础信息、自查结果和用户提交的 `symptoms` 组合为完整诊断描述：该完整描述既传入 AI 诊断队列，也作为报告记录中 `symptoms` 字段的入库内容。拼接格式为：

```
宠物信息：{宠物名称}，{类型}，{品种}，{年龄}；疫苗接种情况：…；驱虫情况：…；生理指标：体温{体温}°C，心率{心率}次/分钟，呼吸频率{呼吸}次/分钟；自查症状：{问题}：{选项}、…；症状描述：{用户填写的病情主诉}
```

其中「疫苗接种情况」「驱虫情况」在宠物无相关记录时整段省略；自查表未勾选任何选项时「自查症状」整段省略。客户端提交时 `symptoms` 仍只需传用户填写的病情主诉原文。

**请求体：**

```json
{
  "petId": 5,
  "symptoms": "狗狗最近两天不吃东西，精神萎靡",
  "selfCheckSnapshot": [
    {
      "listId": 1,
      "listName": "宠物日常健康自查",
      "listType": "PUBLIC",
      "petCategoryId": null,
      "questions": [
        {
          "questionId": 1,
          "questionText": "宠物的食欲是否正常？",
          "questionType": "SINGLE",
          "sortOrder": 0,
          "options": [
            {
              "optionId": 1,
              "optionText": "正常",
              "selected": false
            },
            {
              "optionId": 2,
              "optionText": "不正常",
              "selected": true
            }
          ]
        }
      ]
    }
  ]
}
```

**响应示例：**

```json
{
  "code": 0,
  "data": {
    "id": 1,
    "userId": 10,
    "petId": 5,
    "status": "PROCESSING",
    "symptoms": "宠物信息：旺财，狗，金毛，1岁3个月；生理指标：体温39.5°C，心率120次/分钟，呼吸频率30次/分钟；自查症状：是否呕吐？：是；症状描述：狗狗最近两天不吃东西，精神萎靡",
    "selfCheckSnapshot": [...],
    "createdAt": "2026-01-25T12:00:00.000Z",
    "updatedAt": "2026-01-25T12:00:00.000Z"
  },
  "message": "AI 问诊报告创建成功，正在生成诊断结果"
}
```

### 删除 AI 问诊报告

- **接口**: `DELETE /ai-diagnosis-reports/:id`
- **权限**: ✅ SUPER_ADMIN
- **功能**: 软删除报告（仅超级管理员可操作）

**路径参数：**

| 参数 | 类型   | 必填 | 说明    |
| ---- | ------ | ---- | ------- |
| id   | number | 是   | 报告 ID |

**响应示例：**

```json
{
  "code": 0,
  "message": "报告删除成功"
}
```

### 根据手机号查询宠物列表

- **接口**: `GET /users/phone/:phone/pets`
- **权限**: ✅ SUPER_ADMIN, DOCTOR
- **功能**: 根据用户手机号查询其宠物列表

**路径参数：**

| 参数  | 类型   | 必填 | 说明       |
| ----- | ------ | ---- | ---------- |
| phone | string | 是   | 用户手机号 |

**响应示例：**

```json
{
  "code": 0,
  "data": [
    {
      "id": 5,
      "name": "旺财",
      "categoryId": 1,
      "subCategoryId": 3,
      "age": 3,
      "gender": 1,
      "avatar": "https://example.com/avatar.jpg",
      "userId": 10,
      "userName": "张三"
    }
  ]
}
```

---

**技术架构说明：**

1. **队列处理**:
   - 西医诊断队列: `western-diagnosis`
   - 中医诊断队列: `tcm-diagnosis`
   - 两个队列并行处理，互不影响

2. **重试机制**:
   - 最多重试 3 次
   - 失败后 5 分钟重试
   - 8 小时超时保护

3. **状态流转**:
   - PENDING → PROCESSING → COMPLETED
   - 如果失败: PENDING → PROCESSING → FAILED
   - 如果超时: PROCESSING → TIMEOUT

4. **第三方接口**:
   - 西医诊断: `POST /api/v1/vet/diagnose`
   - 中医诊断: `POST /api/v1/vet/herb`
   - 基础地址: `http://152.32.128.33:18082`
   - 超时设置: 30 秒

---

## Health Appointments 模块

健康预约管理模块（疫苗接种、驱虫、体检）

### 预约类型

| 值        | 说明     |
| --------- | -------- |
| vaccine   | 疫苗接种 |
| deworming | 驱虫     |
| checkup   | 体检     |

### 预约状态

| 值        | 说明   |
| --------- | ------ |
| pending   | 待确认 |
| confirmed | 已确认 |
| completed | 已完成 |
| cancelled | 已取消 |

### 预约管理接口

| HTTP 方法 | 路径 | 描述 | 权限 |
| --- | --- | --- | --- |
| POST | /health-appointments | 创建健康预约 | ✅ USER |
| GET | /health-appointments | 获取预约列表（分页、筛选） | ✅ USER / SUPER_ADMIN / HOSPITAL_ADMIN / STAFF / DOCTOR |
| GET | /health-appointments/:id | 获取预约详情 | ✅ USER / SUPER_ADMIN / HOSPITAL_ADMIN / STAFF / DOCTOR |
| GET | /health-appointments/pet/:petId | 获取指定宠物的预约列表 | ✅ USER / SUPER_ADMIN / HOSPITAL_ADMIN / STAFF / DOCTOR |
| PATCH | /health-appointments/:id/status | 更新预约状态 | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF / DOCTOR |
| PATCH | /health-appointments/:id/complete | 完成预约（可设置下次预约时间） | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF / DOCTOR |
| PATCH | /health-appointments/:id/cancel | 取消预约 | ✅ USER / SUPER_ADMIN / HOSPITAL_ADMIN / STAFF / DOCTOR |
| DELETE | /health-appointments/:id | 删除预约（软删除） | ✅ USER |

### 创建预约

**端点:** `POST /health-appointments`

**描述:** 用户为宠物创建健康预约（疫苗接种、驱虫、体检）

**请求体:**

```json
{
  "petId": 1,
  "hospitalId": 1,
  "type": "vaccine",
  "appointmentDate": "2026-01-26",
  "timeSlot": "09:00-10:00",
  "notes": "备注信息（可选）"
}
```

**时间段选项:**

- 09:00-10:00
- 10:00-11:00
- 11:00-12:00
- 13:00-14:00
- 14:00-15:00
- 15:00-16:00
- 16:00-17:00
- 17:00-18:00

### 获取预约列表

**端点:** `GET /health-appointments`

**描述:** 获取健康预约列表，支持分页和多条件筛选

**查询参数:** | 参数 | 类型 | 必填 | 说明 | |------|------|------|------| | page | number | 否 | 页码，默认 1 | | pageSize | number | 否 | 每页条数，默认 10 | | petId | number | 否 | 宠物 ID | | petName | string | 否 | 宠物名称（模糊搜索） | | ownerPhone | string | 否 | 主人手机号（精确匹配） | | type | string | 否 | 预约类型：vaccine/deworming/checkup | | status | string/array | 否 | 预约状态：可传单个状态（如：pending）、逗号分隔的多个状态（如：pending,confirmed）或状态数组（如：["pending", "confirmed"]） | | hospitalId | number | 否 | 医院 ID |

**多状态筛选示例（推荐使用逗号分隔）:**

```
GET /health-appointments?status=pending,confirmed
```

**列表返回结构说明:**

- `data` 中的每一项与详情接口返回字段一致
- `doctor` 仅在预约已分配医生时返回
- `operationContent`、`detailContent` 仅在预约完成后返回

**响应示例:**

```json
{
  "code": 0,
  "data": [
    {
      "id": 1,
      "type": "vaccine",
      "status": "pending",
      "appointmentDate": "2026-01-26",
      "timeSlot": "09:00-10:00",
      "petId": 1,
      "hospitalId": 1,
      "userId": 1,
      "notes": "首次疫苗接种",
      "pet": {
        "id": 1,
        "name": "旺财",
        "avatar": "/uploads/avatar.jpg",
        "category": { "id": 1, "name": "猫" },
        "subCategory": { "id": 2, "name": "英短" }
      },
      "user": {
        "id": 1,
        "username": "张三",
        "phone": "13800138000"
      },
      "hospital": {
        "id": 1,
        "name": "宠物医院总院"
      },
      "doctor": {
        "id": 3,
        "name": "王医生",
        "phone": "13800138003",
        "avatar": "/uploads/doctors/wang.jpg"
      },
      "createdAt": "2026-01-25T10:00:00Z",
      "updatedAt": "2026-01-25T10:00:00Z"
    }
  ],
  "message": "Success",
  "pagination": {
    "total": 100,
    "page": 1,
    "pageSize": 10,
    "totalPages": 10
  }
}
```

### 获取预约详情

**端点:** `GET /health-appointments/:id`

**描述:** 返回单条预约的完整信息；普通用户只能查看自己的预约

**响应示例:**

```json
{
  "code": 0,
  "data": {
    "id": 1,
    "type": "checkup",
    "status": "completed",
    "appointmentDate": "2026-01-26T00:00:00.000Z",
    "timeSlot": "09:00-10:00",
    "petId": 1,
    "hospitalId": 1,
    "userId": 1,
    "doctorId": 3,
    "notes": "复查完成",
    "operationContent": "常规体检与驱虫复查",
    "detailContent": "<p>体温、心率正常，无明显异常。</p>",
    "pet": {
      "id": 1,
      "name": "旺财"
    },
    "hospital": {
      "id": 1,
      "name": "宠物医院总院"
    },
    "user": {
      "id": 1,
      "username": "张三",
      "phone": "13800138000"
    },
    "doctor": {
      "id": 3,
      "name": "王医生",
      "phone": "13800138003"
    },
    "createdAt": "2026-01-25T10:00:00.000Z",
    "updatedAt": "2026-01-26T09:30:00.000Z"
  },
  "message": "Success"
}
```

### 更新预约状态

**端点:** `PATCH /health-appointments/:id/status`

**描述:** 更新预约状态（用于确认预约）

**请求体:**

```json
{
  "status": "confirmed",
  "doctorId": 1
}
```

**字段说明:** | 字段 | 类型 | 必填 | 说明 | |------|------|------|------| | status | string | 是 | 预约状态：pending=待确认, confirmed=已确认, completed=已完成, cancelled=已取消 | | doctorId | number | 否 | 医生 ID（确认预约时可选择医生） |

### 完成预约

**端点:** `PATCH /health-appointments/:id/complete`

**描述:** 完成预约，可选设置下次预约时间，可记录本次操作内容和详情。完成后会自动更新宠物的健康记录。

**请求体:**

```json
{
  "nextAppointmentDate": "2026-02-26",
  "operationContent": "本次操作内容（可选）",
  "detailContent": "<p>详情内容（支持富文本）</p>",
  "notes": "备注（可选）"
}
```

**字段说明:** | 字段 | 类型 | 必填 | 说明 | |------|------|------|------| | nextAppointmentDate | string | 否 | 下次预约日期，格式：YYYY-MM-DD | | operationContent | string | 否 | 本次操作内容，如：接种疫苗、驱虫处理、体检项目等，最多 1000 字符 | | detailContent | string | 否 | 详情内容，支持富文本格式，记录详细的操作过程和结果 | | notes | string | 否 | 简短备注，最多 500 字符 |

**业务逻辑:**

1. 预约状态改为 `completed`
2. 如果提供了 `nextAppointmentDate`，根据预约类型更新宠物表的对应字段：
   - **vaccine**: 更新 `nextVaccineAt`、`lastVaccineAt`、`vaccineCount`
   - **deworming**: 更新 `nextDewormingAt`、`lastDewormingAt`、`dewormingCount`
   - **checkup**: 更新 `nextCheckupAt`、`lastCheckupAt`、`checkupCount`
3. 如果没有提供 `nextAppointmentDate`，仍会更新 `last*At` 和 `*Count` 字段

### 取消预约

**端点:** `PATCH /health-appointments/:id/cancel`

**描述:** 取消预约。普通用户只能取消自己的预约；管理端角色可以取消任意预约。已完成预约不可取消。

### 获取宠物预约历史

**端点:** `GET /health-appointments/pet/:petId`

**描述:** 获取指定宠物的所有预约记录

**查询参数:** | 参数 | 类型 | 必填 | 说明 | |------|------|------|------| | page | number | 否 | 页码，默认 1 | | pageSize | number | 否 | 每页条数，默认 10 | | status | string | 否 | 筛选预约状态 |

### 权限说明

| 角色           | 权限                                   |
| -------------- | -------------------------------------- |
| USER           | 创建/查看/取消/删除自己的预约          |
| SUPER_ADMIN    | 全部权限                               |
| HOSPITAL_ADMIN | 查看和管理预约，可确认、取消、完成预约 |
| STAFF          | 查看和管理预约，可确认、取消、完成预约 |
| DOCTOR         | 查看和管理预约，可确认、取消、完成预约 |

---

## System Configs 模块

系统配置相关接口

| HTTP 方法 | 路径                 | 描述                     | 权限           |
| --------- | -------------------- | ------------------------ | -------------- |
| GET       | /system-configs      | 获取所有配置列表（分页） | ✅ SUPER_ADMIN |
| GET       | /system-configs/:key | 根据 configKey 获取配置  | 🌐             |
| POST      | /system-configs      | 创建新配置               | ✅ SUPER_ADMIN |
| PUT       | /system-configs/:key | 根据 configKey 更新配置  | ✅ SUPER_ADMIN |
| DELETE    | /system-configs/:key | 删除配置                 | ✅ SUPER_ADMIN |

### 请求示例

```typescript
// 获取联系方式配置
GET /system-configs/contact_info

// 获取平台手续费配置
GET /system-configs/platform_fee_rate

// 获取急救中心配置
GET /system-configs/emergency_center

// 获取 App 首页菜单图标配置
GET /system-configs/home_menu_icons

// 获取 App 首页 AI 智能诊断 Banner 配置
GET /system-configs/home_ai_diagnosis_banner

// 获取商城首页图片弹窗配置
GET /system-configs/mall_home_popup_image

// 获取医疗首页滚动公告配置
GET /system-configs/scrolling_announcement

// 获取 AI 问诊配置
GET /system-configs/ai_diagnosis_config

// 获取医疗咨询配置
GET /system-configs/medical_consultation_config

// 更新联系方式配置
PUT /system-configs/contact_info
{
  "configValue": {
    "wechatQrCode": "http://example.com/wechat.jpg",
    "hotline": "400-123-4567",
    "workingHours": "周一至周五 9:00-18:00"
  },
  "description": "联系方式配置"
}

// 更新平台手续费配置
PUT /system-configs/platform_fee_rate
{
  "configValue": {
    "feeRate": 5
  },
  "description": "平台手续费率配置（百分比）"
}

// 更新急救中心配置
PUT /system-configs/emergency_center
{
  "configValue": {
    "emergencyTime": "24小时在线",
    "emergencyHotline": "400-000-0000"
  },
  "description": "急救中心配置"
}

// 更新 App 首页菜单图标配置
PUT /system-configs/home_menu_icons
{
  "configValue": {
    "icons": {
      "pet-list": "/uploads/home-menu-pet.png",
      "gold-doctor": "/uploads/home-menu-gold-doctor.png",
      "emergency": "/uploads/home-menu-emergency.png",
      "health": "/uploads/home-menu-health.png",
      "nearby": "/uploads/home-menu-nearby.png",
      "charity": "/uploads/home-menu-charity.png",
      "lost-found": "/uploads/home-menu-lost-found.png",
      "activity": "/uploads/home-menu-activity.png",
      "community": "/uploads/home-menu-community.png",
      "second-hand-mall": "/uploads/home-menu-second-hand-mall.png"
    }
  },
  "description": "App 首页菜单图标配置"
}

// 更新 App 首页 AI 智能诊断 Banner 配置
PUT /system-configs/home_ai_diagnosis_banner
{
  "configValue": {
    "imageUrl": "/uploads/home-ai-diagnosis-banner.png"
  },
  "description": "App 首页AI智能诊断Banner配置"
}

// 更新 AI 问诊配置
PUT /system-configs/ai_diagnosis_config
{
  "configValue": {
    "bodyTemperatureOptions": [
      "偏低（低于37.5℃）",
      "正常（37.5℃ - 39.2℃）",
      "偏高（39.3℃ - 40℃）",
      "高热（高于40℃）"
    ],
    "heartRateOptions": ["偏慢", "正常", "偏快", "明显过快"],
    "breatheOptions": ["偏慢", "正常", "偏快", "呼吸困难"],
    "disclaimerTitle": "风险提示",
    "disclaimerContent": "AI问诊结果仅供参考，不能替代线下执业兽医诊疗。",
    "disclaimerConfirmText": "我已知晓，继续问诊",
    "disclaimerCancelText": "再想想"
  },
  "description": "AI问诊基础配置"
}

// 更新医疗咨询配置
PUT /system-configs/medical_consultation_config
{
  "configValue": {
    "paymentPromptDisclaimer": "在线咨询仅供宠物健康管理参考，不能替代线下诊疗。若宠物出现急症或症状加重，请及时前往正规宠物医院就诊。"
  },
  "description": "医疗咨询基础配置"
}
```

### 配置值示例

**联系方式配置** (contact_info):

```json
{
  "wechatQrCode": "微信二维码图片 URL",
  "hotline": "客服热线",
  "workingHours": "工作时间描述"
}
```

**平台手续费配置** (platform_fee_rate):

```json
{
  "feeRate": 5
}
```

**急救中心配置** (emergency_center):

```json
{
  "emergencyTime": "24小时在线",
  "emergencyHotline": "400-000-0000"
}
```

**App 首页菜单图标配置** (home_menu_icons):

```json
{
  "icons": {
    "pet-list": "宠物档案图标 URL",
    "gold-doctor": "金牌咨询图标 URL",
    "emergency": "急救中心图标 URL",
    "health": "营养师图标 URL",
    "nearby": "附近图标 URL",
    "charity": "公益中心图标 URL",
    "lost-found": "走失领养图标 URL",
    "activity": "活动管理图标 URL",
    "community": "宠物社区图标 URL",
    "second-hand-mall": "二手商城图标 URL"
  }
}
```

**App 首页 AI 智能诊断 Banner 配置** (home_ai_diagnosis_banner):

```json
{
  "imageUrl": "首页 AI 智能诊断 Banner 图片 URL"
}
```

**商城首页图片弹窗配置** (mall_home_popup_image):

```json
{
  "imageUrl": "https://example.com/mall-popup.jpg"
}
```

后台“系统配置 > 首页菜单”维护此配置，使用 ImageUpload 直接上传原图。默认 `imageUrl` 为空，不显示弹窗。配置后每次切换进入商城首页展示一次，刷新和加购不重复弹出；支持关闭和长按保存到相册。`/uploads/` 相对路径沿用 APP 的 COS 图片地址解析规则，保存时转换为 PNG。

**医疗首页滚动公告配置** (scrolling_announcement):

```json
{
  "source": "fixed",
  "announcementText": "欢迎来到谷德E宠"
}
```

后台“系统配置 > 滚动公告”维护此配置。`source` 支持 `fixed`（固定文案）、`donation`（最新捐赠记录）、`disabled`（关闭）；默认 `fixed` 且文案为空，首页隐藏公告。固定内容会归一化空白，超过一行时滚动展示；捐赠模式读取 `GET /charity/latest-donations` 并按来源显示“公益捐赠”或“在商城下单公益捐赠”。配置或捐赠接口失败时隐藏公告，其他首页区块仍正常加载。

以上两项均使用现有的 `PUT /system-configs/:key` 保存，提交 `{ "configValue": { ... } }`，需要 SUPER_ADMIN 权限；缺失时可通过现有 `POST /system-configs` 创建。读取为公开接口。服务启动时仅补齐缺失的默认配置，不覆盖已有内容。

**AI 问诊配置** (ai_diagnosis_config):

```json
{
  "bodyTemperatureOptions": [
    "偏低（低于37.5℃）",
    "正常（37.5℃ - 39.2℃）",
    "偏高（39.3℃ - 40℃）",
    "高热（高于40℃）"
  ],
  "heartRateOptions": ["偏慢", "正常", "偏快", "明显过快"],
  "breatheOptions": ["偏慢", "正常", "偏快", "呼吸困难"],
  "disclaimerTitle": "风险提示",
  "disclaimerContent": "AI问诊结果仅供参考，不能替代线下执业兽医诊疗。",
  "disclaimerConfirmText": "我已知晓，继续问诊",
  "disclaimerCancelText": "再想想"
}
```

**医疗咨询配置** (medical_consultation_config):

```json
{
  "paymentPromptDisclaimer": "免费咨询次数用完后，付费提示上方展示的免责声明"
}
```

说明：

- `feeRate` 范围为 `0-100`，单位为百分比。
- 用户发布商品成交后，卖家待审核入账金额 = 用户发布商品成交金额 - 平台手续费。
- 后台“系统配置”页会直接维护该配置。
- `emergency_center` 用于 APP 端紧急求助页面的急救时间和急救热线。
- 后台“系统配置 > 急救中心”页会直接维护该配置。
- `home_menu_icons` 用于 APP 端首页 10 个菜单入口的自定义图标。
- 后台“系统配置 > 首页菜单”页会直接维护该配置；未上传的菜单会继续使用 APP 默认图标和背景色。
- `home_ai_diagnosis_banner` 用于 APP 端首页菜单上方 AI 智能诊断横幅图片。
- 后台“系统配置 > 首页菜单”页会直接维护该配置；未上传时 APP 端继续显示本地默认横幅图片。
- `ai_diagnosis_config` 用于 APP 端 AI 问诊页面的基础信息下拉选项和免责声明文案。
- 后台“AI 问诊管理 > 问诊配置”页会直接维护该配置。
- `medical_consultation_config` 用于 APP 聊天页免费咨询次数用完后的付费提示免责声明。
- 后台“系统配置 > 医疗咨询”页会直接维护该配置，使用普通输入框，不使用富文本。

### 字段说明

**SystemConfig 对象:** | 字段 | 类型 | 说明 | |------|------|------| | id | number | 配置 ID | | configKey | string | 配置标识（唯一） | | configValue | object | 配置值（JSON 格式） | | description | string | 配置说明 | | createdAt | string | 创建时间 | | updatedAt | string | 更新时间 |

**创建配置参数:** | 字段 | 类型 | 必填 | 说明 | |------|------|------|------| | configKey | string | 是 | 配置标识（全局唯一） | | configValue | object | 是 | 配置值（JSON 格式） | | description | string | 否 | 配置说明 |

**更新配置参数:** | 字段 | 类型 | 必填 | 说明 | |------|------|------|------| | configValue | object | 是 | 配置值（JSON 格式） | | description | string | 否 | 配置说明 |

**查询参数:** | 参数 | 类型 | 必填 | 说明 | |------|------|------|------| | page | number | 否 | 页码，默认 1 | | pageSize | number | 否 | 每页条数，默认 10 | | configKey | string | 否 | 筛选配置标识（模糊查询） |

---

## Aid Guides 模块

急救指南管理相关接口

| HTTP 方法 | 路径                              | 描述                 | 权限           |
| --------- | --------------------------------- | -------------------- | -------------- |
| GET       | /aid-guides/categories            | 获取分类列表（分页） | 🌐             |
| GET       | /aid-guides/categories/:id        | 获取分类详情         | 🌐             |
| POST      | /aid-guides/categories            | 创建分类             | ✅ SUPER_ADMIN |
| PUT       | /aid-guides/categories/:id        | 更新分类             | ✅ SUPER_ADMIN |
| PATCH     | /aid-guides/categories/:id/status | 启用/禁用分类        | ✅ SUPER_ADMIN |
| DELETE    | /aid-guides/categories/:id        | 删除分类             | ✅ SUPER_ADMIN |
| GET       | /aid-guides                       | 获取指南列表（分页） | 🌐             |
| GET       | /aid-guides/:id                   | 获取指南详情         | 🌐             |
| POST      | /aid-guides                       | 创建指南             | ✅ SUPER_ADMIN |
| PUT       | /aid-guides/:id                   | 更新指南             | ✅ SUPER_ADMIN |
| PATCH     | /aid-guides/:id/status            | 发布/下架指南        | ✅ SUPER_ADMIN |
| DELETE    | /aid-guides/:id                   | 删除指南             | ✅ SUPER_ADMIN |
| GET       | /aid-guides/category/:categoryId  | 获取指定分类下的指南 | 🌐             |

### 1. 分类管理

#### 1.1 获取分类列表

**接口地址:** `GET /server-api/aid-guides/categories`

**请求参数:**

| 参数     | 类型    | 必填 | 说明              |
| -------- | ------- | ---- | ----------------- |
| page     | number  | 否   | 页码，默认 1      |
| pageSize | number  | 否   | 每页数量，默认 10 |
| isActive | boolean | 否   | 是否启用          |
| keyword  | string  | 否   | 搜索关键词        |

**响应示例:**

\`\`\`json { "code": 0, "data": [ { "id": 1, "name": "心肺复苏", "icon": "https://xxx.com/icon.png", "sortOrder": 1, "isActive": true, "guideCount": 5, "createdAt": "2026-01-27T10:00:00.000Z", "updatedAt": "2026-01-27T10:00:00.000Z" } ], "pagination": { "total": 10, "page": 1, "pageSize": 10 } } \`\`\`

#### 1.2 创建分类

**接口地址:** `POST /server-api/aid-guides/categories`

**请求参数:**

| 参数      | 类型    | 必填 | 说明                |
| --------- | ------- | ---- | ------------------- |
| name      | string  | 是   | 分类名称            |
| icon      | string  | 否   | 分类图标 URL        |
| sortOrder | number  | 否   | 排序权重，默认 0    |
| isActive  | boolean | 否   | 是否启用，默认 true |

**请求示例:**

\`\`\`json { "name": "心肺复苏", "icon": "https://example.com/icon.png", "sortOrder": 1, "isActive": true } \`\`\`

#### 1.3 其他分类接口

- `GET /server-api/aid-guides/categories/:id` - 获取分类详情
- `PUT /server-api/aid-guides/categories/:id` - 更新分类
- `PATCH /server-api/aid-guides/categories/:id/status` - 启用/禁用分类
- `DELETE /server-api/aid-guides/categories/:id` - 删除分类

### 2. 指南管理

#### 2.1 获取指南列表

**接口地址:** `GET /server-api/aid-guides`

**请求参数:**

| 参数       | 类型   | 必填 | 说明                    |
| ---------- | ------ | ---- | ----------------------- |
| page       | number | 否   | 页码，默认 1            |
| pageSize   | number | 否   | 每页数量，默认 10       |
| categoryId | number | 否   | 分类 ID                 |
| status     | string | 否   | 状态（DRAFT/PUBLISHED） |
| keyword    | string | 否   | 搜索关键词              |

**响应示例:**

\`\`\`json { "code": 0, "data": [ { "id": 1, "title": "宠物心肺复苏步骤", "icon": "https://xxx.com/icon.png", "content": "<p>步骤 1：检查呼吸...</p>", "categoryId": 1, "category": { "id": 1, "name": "心肺复苏" }, "status": "PUBLISHED", "sortOrder": 1, "publishedAt": "2026-01-27T10:00:00.000Z", "authorId": 1, "createdAt": "2026-01-27T10:00:00.000Z", "updatedAt": "2026-01-27T10:00:00.000Z" } ], "pagination": { "total": 20, "page": 1, "pageSize": 10 } } \`\`\`

#### 2.2 创建指南

**接口地址:** `POST /server-api/aid-guides`

**请求参数:**

| 参数       | 类型   | 必填 | 说明                                |
| ---------- | ------ | ---- | ----------------------------------- |
| title      | string | 是   | 指南标题                            |
| icon       | string | 否   | 指南图标 URL                        |
| content    | string | 是   | 指南内容（HTML 富文本）             |
| categoryId | number | 是   | 所属分类 ID                         |
| sortOrder  | number | 否   | 排序权重，默认 0                    |
| status     | string | 否   | 状态（DRAFT/PUBLISHED），默认 DRAFT |

**请求示例:**

\`\`\`json { "title": "宠物心肺复苏步骤", "icon": "https://example.com/icon.png", "content": "<p>步骤 1：检查呼吸...</p>", "categoryId": 1, "sortOrder": 1, "status": "PUBLISHED" } \`\`\`

#### 2.3 其他指南接口

- `GET /server-api/aid-guides/:id` - 获取指南详情
- `PUT /server-api/aid-guides/:id` - 更新指南
- `PATCH /server-api/aid-guides/:id/status` - 发布/下架指南
- `DELETE /server-api/aid-guides/:id` - 删除指南
- `GET /server-api/aid-guides/category/:categoryId` - 获取指定分类下的指南

### 3. 权限说明

| 角色        | 权限                                     |
| ----------- | ---------------------------------------- |
| USER        | 只能查询已发布的指南（status=PUBLISHED） |
| DOCTOR      | 只能查询已发布的指南（status=PUBLISHED） |
| SUPER_ADMIN | 完整的 CRUD 权限，包括草稿管理           |

---

**文档最后更新时间:** 2026-03-24

---

## 系统文章管理 API

### 1. 获取所有文章

- **接口**: `GET /server-api/system-articles`
- **权限**: 🌐 公开接口（无需登录）
- **返回**: 文章列表数组
- **说明**: 用于 APP 未登录场景展示隐私协议、用户协议、关于我们等系统内容

**示例**:

```typescript
import { getSystemArticlesListApi } from '@/api-new/system-articles'

const articles = await getSystemArticlesListApi()
// 返回: [{ id: 1, type: 'about_us', content: '...', ... }]
```

---

### 2. 获取指定类型文章

- **接口**: `GET /server-api/system-articles/:type`
- **参数**:
  - `type`: 文章类型 (`about_us` | `privacy` | `user_agreement`)
- **权限**: 🌐 公开接口（无需登录）
- **返回**: 文章详情
- **说明**: 新用户首次启动 APP 时会在未登录状态请求 `privacy` 类型文章

**示例**:

```typescript
import { getSystemArticleByTypeApi, ArticleType } from '@/api-new/system-articles'

const article = await getSystemArticleByTypeApi(ArticleType.ABOUT_US)
// 返回: { id: 1, type: 'about_us', content: '...', ... }
```

---

### 3. 更新文章

- **接口**: `PUT /server-api/system-articles/:type`
- **参数**:
  - `type`: 文章类型
  - `content`: 文章内容（HTML 字符串）
- **权限**: ✅ 需要登录（当前后端未限制角色）
- **返回**: 更新后的文章

**示例**:

```typescript
import { updateSystemArticleApi, ArticleType } from '@/api-new/system-articles'

const article = await updateSystemArticleApi(ArticleType.ABOUT_US, '<p>更新后的内容</p>')
```

**请求体**:

```json
{
  "content": "<h1>关于我们</h1><p>这是我们的公司介绍...</p>"
}
```

---

### 4. 初始化文章（仅首次使用）

- **接口**: `POST /server-api/system-articles/init`
- **权限**: ✅ 需要登录（当前后端未限制角色）
- **返回**: 初始化的文章数组

**示例**:

```typescript
import { initSystemArticlesApi } from '@/api-new/system-articles'

const articles = await initSystemArticlesApi()
// 返回: 3 条初始化的文章记录
```

---

## 数据类型定义

```typescript
/**
 * 文章类型枚举
 */
enum ArticleType {
  ABOUT_US = 'about_us', // 关于我们
  PRIVACY = 'privacy', // 隐私协议
  USER_AGREEMENT = 'user_agreement' // 用户协议
}

/**
 * 系统文章实体
 */
interface SystemArticle {
  id: number // 主键ID
  type: ArticleType // 文章类型
  content: string // 文章内容(HTML)
  createdAt: string // 创建时间
  updatedAt: string // 更新时间
}
```

---

## 权限说明

| 角色       | 权限                                                             |
| ---------- | ---------------------------------------------------------------- |
| USER       | 只能查询文章                                                     |
| DOCTOR     | 只能查询文章                                                     |
| 已登录用户 | 当前后端实现允许读取、更新和初始化；若后续增加角色守卫需同步文档 |

---

## AI Diagnosis Report 模块

AI 诊断报告相关接口，用于创建和查询 AI 诊断报告

| HTTP 方法 | 路径                      | 描述                      | 权限           |
| --------- | ------------------------- | ------------------------- | -------------- |
| POST      | /ai-diagnosis-reports     | 创建 AI 诊断报告          | ✅             |
| GET       | /ai-diagnosis-reports     | 获取报告列表（分页+筛选） | ✅             |
| GET       | /ai-diagnosis-reports/:id | 获取报告详情              | ✅             |
| DELETE    | /ai-diagnosis-reports/:id | 删除报告                  | 🎭 SUPER_ADMIN |

---

### 1. 创建 AI 诊断报告

**端点:** `POST /ai-diagnosis-reports`

**描述:** 提交健康评估数据，系统会自动调用 AI 服务生成诊断报告

**权限:** USER（普通用户）

**请求体:**

```json
{
  "petId": 1,
  "symptoms": "宠物呕吐、腹泻，精神不振",
  "selfCheckSnapshot": [
    {
      "listId": 1,
      "listName": "消化系统自查",
      "listType": "PUBLIC",
      "petCategoryId": 1,
      "questions": [
        {
          "questionId": 1,
          "questionText": "是否呕吐？",
          "questionType": "SINGLE",
          "sortOrder": 1,
          "options": [
            {
              "optionId": 1,
              "optionText": "是",
              "image": "/images/symptom1.jpg",
              "selected": true
            }
          ]
        }
      ]
    }
  ],
  "diagnosisImages": ["http://example.com/image1.jpg", "http://example.com/image2.jpg"],
  "basicInfo": {
    "bodyTemperature": "39.5°C",
    "heartRate": "120次/分钟",
    "breathe": "30次/分钟"
  }
}
```

**响应体:**

```json
{
  "id": 1,
  "userId": 1,
  "petId": 1,
  "petName": "小白",
  "status": "PENDING",
  "symptoms": "宠物信息：小白，猫，英国短毛猫，2岁；生理指标：体温39.5°C，心率120次/分钟，呼吸频率30次/分钟；自查症状：是否呕吐？：是；症状描述：宠物呕吐、腹泻，精神不振",
  "selfCheckSnapshot": [...],
  "diagnosisImages": [...],
  "basicInfo": {
    "bodyTemperature": "39.5°C",
    "heartRate": "120次/分钟",
    "breathe": "30次/分钟"
  },
  "westernDiagnosis": null,
  "tcmDiagnosis": null,
  "errorMessage": null,
  "createdAt": "2026-01-28T10:00:00.000Z",
  "updatedAt": "2026-01-28T10:00:00.000Z",
  "completedAt": null,
  "retryCount": 0
}
```

**示例代码:**

```typescript
import { createAiDiagnosisReportApi } from '@/api-new/ai-diagnosis-report'

const report = await createAiDiagnosisReportApi({
  petId: 1,
  symptoms: '宠物呕吐、腹泻，精神不振',
  selfCheckSnapshot: selfCheckData,
  diagnosisImages: ['http://example.com/image1.jpg'],
  basicInfo: {
    bodyTemperature: '39.5°C',
    heartRate: '120次/分钟',
    breathe: '30次/分钟'
  }
})
```

---

### 2. 获取报告列表

**端点:** `GET /ai-diagnosis-reports`

**描述:** 获取 AI 诊断报告列表，支持分页、筛选和关键词搜索

**权限:** USER（普通用户只能查看自己的报告）

**查询参数:** | 参数 | 类型 | 必填 | 描述 | |------|------|------|------| | page | number | 否 | 页码，默认 1 | | pageSize | number | 否 | 每页数量，默认 10 | | id | number | 否 | 报告 ID 精确搜索 | | userId | number | 否 | 用户 ID 筛选（管理员/医生可筛选） | | userPhone | string | 否 | 用户手机号模糊搜索 | | petId | number | 否 | 宠物 ID 筛选 | | status | string | 否 | 状态筛选（PENDING/PROCESSING/COMPLETED/FAILED/TIMEOUT） | | keyword | string | 否 | 关键词搜索（搜索症状描述） | | startDate | string | 否 | 开始日期（ISO 8601 格式） | | endDate | string | 否 | 结束日期（ISO 8601 格式） |

**响应体:**

```json
{
  "code": 0,
  "data": [
    {
      "id": 1,
      "userId": 1,
      "petId": 1,
      "petName": "小白",
      "userPhone": "13800000000",
      "status": "COMPLETED",
      "symptoms": "宠物信息：小白，猫，英国短毛猫，2岁；生理指标：体温39.5°C，心率120次/分钟，呼吸频率30次/分钟；自查症状：是否呕吐？：是；症状描述：宠物呕吐、腹泻，精神不振",
      "createdAt": "2026-01-28 10:00:00",
      "updatedAt": "2026-01-28 10:05:00",
      "completedAt": "2026-01-28 10:05:00"
    }
  ],
  "pagination": {
    "total": 1,
    "page": 1,
    "pageSize": 10,
    "totalPages": 1
  },
  "message": "获取报告列表成功"
}
```

列表每项返回 `symptoms`（string），为完整诊断描述（与详情接口的同一字段一致），供客户端问诊记录卡片展示；为空字符串时客户端显示“暂无症状描述”。自查表、图片、诊断结果等完整内容请通过详情接口获取。

**示例代码:**

```typescript
import { getAiDiagnosisReportsByPetIdApi } from '@/api-new/ai-diagnosis-report'

// 获取指定宠物的报告列表
const reports = await getAiDiagnosisReportsByPetIdApi(1)
```

---

### 3. 获取报告详情

**端点:** `GET /ai-diagnosis-reports/:id`

**描述:** 获取指定报告的完整详情，包括 AI 诊断结果

**权限:** USER（普通用户只能查看自己的报告）

**响应体:**

```json
{
  "id": 1,
  "userId": 1,
  "petId": 1,
  "petName": "小白",
  "status": "COMPLETED",
  "symptoms": "宠物信息：小白，猫，英国短毛猫，2岁；生理指标：体温39.5°C，心率120次/分钟，呼吸频率30次/分钟；自查症状：是否呕吐？：是；症状描述：宠物呕吐、腹泻，精神不振",
  "selfCheckSnapshot": [
    {
      "listId": 1,
      "listName": "消化系统自查",
      "listType": "PUBLIC",
      "petCategoryId": 1,
      "questions": [
        {
          "questionId": 1,
          "questionText": "是否呕吐？",
          "questionType": "SINGLE",
          "sortOrder": 1,
          "options": [
            {
              "optionId": 1,
              "optionText": "是",
              "image": "/images/symptom1.jpg",
              "selected": true
            }
          ]
        }
      ]
    }
  ],
  "diagnosisImages": ["http://example.com/image1.jpg", "http://example.com/image2.jpg"],
  "basicInfo": {
    "bodyTemperature": "39.5°C",
    "heartRate": "120次/分钟",
    "breathe": "30次/分钟"
  },
  "westernDiagnosis": {
    "diagnosis": [
      {
        "symptom": "急性胃扩张",
        "reason": "短时间内大量饮水、进食过快...",
        "probability": 0.4
      }
    ],
    "medications": [
      {
        "symptom": "急性胃扩张",
        "drug_name": "甲氧氯普胺",
        "dosage": "0.2-0.5 mg/kg PO q8h",
        "frequency": "q8h"
      }
    ]
  },
  "tcmDiagnosis": {
    "data": [
      {
        "zhengming": "胃气上逆证",
        "description": "幼犬脾胃功能尚未健全...",
        "p": 0.85,
        "therapy": "和胃降逆，理气止呕",
        "base": "暂停喂食喂水4-6小时...",
        "base_prescription": "小半夏汤加减",
        "base_prescription_usage": "半夏6g、生姜3片..."
      }
    ]
  },
  "errorMessage": null,
  "createdAt": "2026-01-28T10:00:00.000Z",
  "updatedAt": "2026-01-28T10:05:00.000Z",
  "completedAt": "2026-01-28T10:05:00.000Z",
  "retryCount": 0
}
```

**示例代码:**

```typescript
import { getAiDiagnosisReportDetailApi } from '@/api-new/ai-diagnosis-report'

const report = await getAiDiagnosisReportDetailApi(1)
```

---

### 4. 删除报告

**端点:** `DELETE /ai-diagnosis-reports/:id`

**描述:** 删除指定的 AI 诊断报告（仅超级管理员）

**权限:** SUPER_ADMIN

**响应体:**

```json
{
  "message": "报告删除成功"
}
```

---

## 数据类型定义

```typescript
/**
 * 报告状态枚举
 */
enum AiDiagnosisStatus {
  PENDING = 'PENDING', // 待生成
  PROCESSING = 'PROCESSING', // 生成中
  COMPLETED = 'COMPLETED', // 已完成
  FAILED = 'FAILED', // 生成失败
  TIMEOUT = 'TIMEOUT' // 已超时
}

/**
 * 自查表选项快照
 */
interface SelfCheckOptionSnapshot {
  optionId: number // 选项ID
  optionText: string // 选项文本
  image?: string // 选项图片
  selected: boolean // 是否被用户选中
}

/**
 * 自查表问题快照
 */
interface SelfCheckQuestionSnapshot {
  questionId: number // 问题ID
  questionText: string // 问题文本
  questionType: 'SINGLE' | 'MULTIPLE' | 'TEXT' // 问题类型
  sortOrder: number // 排序
  options: SelfCheckOptionSnapshot[]
}

/**
 * 自查表快照
 */
interface SelfCheckListSnapshot {
  listId: number // 自查表ID
  listName: string // 自查表名称
  listType: 'PUBLIC' | 'SPECIFIC' // 类型：公共项/特定项
  petCategoryId: number // 宠物分类ID
  questions: SelfCheckQuestionSnapshot[]
}

/**
 * 基础信息
 */
interface BasicInfo {
  bodyTemperature?: string // 体温
  heartRate?: string // 心率
  breathe?: string // 呼吸频率
}

/**
 * 西医诊断结果
 */
interface WesternDiagnosis {
  diagnosis: {
    symptom: string // 症状名称
    reason: string // 诊断理由
    probability: number // 概率 (0-1)
  }[]
  medications: {
    symptom: string // 适用症状
    drug_name: string // 药物名称
    dosage: string // 剂量
    frequency: string // 给药频率
  }[]
}

/**
 * 中医诊断结果
 */
interface TcmDiagnosis {
  data: {
    zhengming: string // 证候名称
    description: string // 描述
    p: number // 概率 (0-1)
    therapy: string // 治疗原则
    base: string // 基础建议
    base_prescription: string // 方药名称
    base_prescription_usage: string // 方药用法
  }[]
}

/**
 * AI诊断报告实体
 */
interface AiDiagnosisReport {
  id: number // 主键ID
  userId: number // 用户ID
  petId: number // 宠物ID
  petName?: string // 宠物名称（关联查询）
  status: AiDiagnosisStatus // 报告状态
  symptoms: string // 完整诊断描述（宠物信息、疫苗/驱虫、生理指标、自查症状、用户主诉）
  selfCheckSnapshot?: SelfCheckListSnapshot[] // 自查表快照
  diagnosisImages?: string[] // 诊断图片列表
  basicInfo?: BasicInfo // 基础信息
  westernDiagnosis?: WesternDiagnosis // 西医诊断结果
  tcmDiagnosis?: TcmDiagnosis // 中医诊断结果
  errorMessage?: string // 错误信息
  createdAt: string // 创建时间
  updatedAt: string // 更新时间
  completedAt?: string // 完成时间
  retryCount?: number // 重试次数
}
```

---

## 权限说明

| 角色        | 权限                                     |
| ----------- | ---------------------------------------- |
| USER        | 创建报告、查看自己的报告、删除自己的报告 |
| DOCTOR      | 查看所有用户的报告（用于诊断参考）       |
| SUPER_ADMIN | 查看所有报告、删除任意报告               |

---

**文档最后更新时间:** 2026-01-28

---

## Statistics 模块

首页统计数据相关接口

### 获取首页统计数据

获取系统核心指标的总数，用于首页展示

**接口信息**：

- **HTTP 方法**: GET
- **路径**: `/statistics/dashboard`
- **认证**: ✅ 需要 JWT 认证
- **权限**: 🎭 SUPER_ADMIN, HOSPITAL_ADMIN, DOCTOR

**请求示例**：

```http
GET /statistics/dashboard
Authorization: Bearer <your-jwt-token>
```

**响应示例**：

```json
{
  "code": 0,
  "data": {
    "hospitals": 12,
    "doctors": 45,
    "users": 1208,
    "pets": 3560
  },
  "message": "Success"
}
```

**响应字段说明**：| 字段 | 类型 | 描述 | |------|------|------| | hospitals | number | 合作医院总数（仅统计启用的医院） | | doctors | number | 在职医生总数（仅统计状态为 ACTIVE 的医生） | | users | number | 注册用户总数（仅统计启用的用户） | | pets | number | 宠物档案总数 |

**TypeScript 类型定义**：

```typescript
/**
 * 首页统计数据
 */
interface DashboardStats {
  /** 合作医院总数 */
  hospitals: number
  /** 在职医生总数 */
  doctors: number
  /** 注册用户总数 */
  users: number
  /** 宠物档案总数 */
  pets: number
}
```

**前端调用示例**：

```typescript
import { getDashboardStatsApi } from '@/api-new/statistics'

// 获取首页统计数据
const fetchStats = async () => {
  try {
    const res = await getDashboardStatsApi()

    if (res?.data) {
      console.log('医院总数:', res.data.hospitals)
      console.log('医生总数:', res.data.doctors)
      console.log('用户总数:', res.data.users)
      console.log('宠物总数:', res.data.pets)
    }
  } catch (error) {
    console.error('获取统计数据失败:', error)
  }
}
```

**注意事项**：

- 此接口采用并行查询策略，一次性获取所有统计数据，提高性能
- 统计数据仅包含有效的记录（已删除/禁用的不计入统计）
- 适用于管理后台首页的数据展示

---

## Friends 模块

好友关系管理模块，支持好友添加、消息发送、实时通讯等功能。

### 接口列表

| HTTP 方法 | 路径                                | 描述                  | 权限 |
| --------- | ----------------------------------- | --------------------- | ---- |
| POST      | /friends/search-by-phone            | 通过手机号搜索用户    | ✅   |
| POST      | /friends/request                    | 发送好友申请          | ✅   |
| GET       | /friends/requests                   | 获取好友申请列表      | ✅   |
| POST      | /friends/requests/:id/accept        | 接受好友申请          | ✅   |
| POST      | /friends/requests/:id/reject        | 拒绝好友申请          | ✅   |
| GET       | /friends                            | 获取好友列表          | ✅   |
| GET       | /friends/relationship/:targetUserId | 获取好友关系摘要      | ✅   |
| POST      | /friends/chat-blocks                | 拉黑好友聊天          | ✅   |
| GET       | /friends/chat-blocks                | 获取好友聊天黑名单    | ✅   |
| DELETE    | /friends/chat-blocks/:blockedUserId | 解除好友聊天拉黑      | ✅   |
| PUT       | /friends/:friendId/remark           | 修改好友备注          | ✅   |
| DELETE    | /friends/:friendId                  | 删除好友              | ✅   |
| POST      | /friends/messages/send              | 发送消息（HTTP 备用） | ✅   |
| POST      | /friends/messages/:messageId/revoke | 撤回本人 2 分钟内发送的消息 | ✅   |
| POST      | /friends/messages/read              | 标记消息已读          | ✅   |
| GET       | /friends/messages/:friendId/history | 获取历史消息          | ✅   |
| GET       | /friends/messages/unread-count      | 获取未读消息数        | ✅   |

### Admin 管理接口

| HTTP 方法 | 路径 | 描述 | 权限 |
| --- | --- | --- | --- |
| GET | /friends/admin/friendships | 获取所有好友关系 | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF |
| GET | /friends/admin/requests | 获取所有好友申请 | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF |
| GET | /friends/admin/messages | 获取所有消息记录 | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF |
| GET | /friends/admin/conversations/:id/messages | 获取会话所有消息 | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF |
| GET | /friends/admin/statistics | 获取统计数据 | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF |
| POST | /friends/admin/requests/handle-expired | 处理过期申请 | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF |

### WebSocket 事件

**命名空间**: `/friends`

**客户端 → 服务器**:

- `friends:join` - 用户上线
- `friends:leave` - 用户离线
- `friends:message:send` - 发送消息
- `friends:message:revoke` - 撤回本人 2 分钟内发送的消息，载荷为 `{"messageId":"..."}`
- `friends:message:read` - 标记已读
- `friends:typing:start` - 开始输入
- `friends:typing:stop` - 停止输入
- `friends:offline:fetch` - 拉取离线消息
- `friends:offline:ack` - 确认离线消息已成功落库

**服务器 → 客户端**:

- `friends:message:new` - 新消息推送
- `friends:message:revoked` - 消息撤回通知，载荷为撤回后的消息对象
- `friends:message:ack` - 消息确认
- `friends:read:receipt` - 已读回执
- `friends:request:new` - 新好友申请
- `friends:request:accepted` - 申请被接受
- `friends:request:rejected` - 申请被拒绝
- `friends:typing:indicator` - 输入状态指示器

### 离线消息确认说明

- 服务端推送离线消息时，会在 `friends:message:new` 中附带 `deliveryMode: "offline"`
- 客户端完成本地持久化后，应发送 `friends:offline:ack`
- 只有收到确认后，服务端才会从 Redis 离线队列中删除对应消息，避免弱网场景下消息提前清理

### WebSocket 消息内容约定

- 文本消息：`content` 直接传纯文本字符串
- 图片消息：`content` 使用 JSON 字符串，格式为 `{"url":"图片地址","width":宽度,"height":高度}`
- 语音消息：`content` 使用 JSON 字符串，格式为 `{"url":"语音地址","duration":时长秒数}`
- 为兼容旧版客户端，服务端仍可接受图片/语音的纯 URL 字符串，但会在落库时统一规范化为 JSON
- `friends:typing:start` 与 `friends:typing:stop` 只允许在真实好友关系且双方均未拉黑好友聊天时发送
- `POST /friends/messages/send` 会复用实时派发逻辑：接收方在线时立即推送，不在线时写入离线队列
- `POST /friends/messages/read` 会复用已读回执逻辑：首次已读时会通知消息发送方
- 撤回仅允许发送者在服务端时间 2 分钟内操作；客户端和离线队列只收到 `content: "消息已撤回"` 的文本占位，后台审计接口保留原内容并通过 `isRevoked`、`revokedAt` 标记。

### 1. 通过手机号搜索用户

**端点:** `POST /friends/search-by-phone`

**请求体:**

```json
{
  "phone": "13800138000"
}
```

**响应:**

```json
{
  "found": true,
  "user": {
    "id": 1,
    "username": "张三",
    "avatar": "https://example.com/avatar.jpg",
    "phone": "13800138000"
  },
  "message": "搜索成功"
}
```

**未找到用户时响应:**

```json
{
  "found": false,
  "user": null,
  "message": "用户不存在"
}
```

### 2. 发送好友申请

**端点:** `POST /friends/request`

**请求体:**

```json
{
  "receiverId": 2,
  "message": "你好，我是李四"
}
```

**响应状态说明:**

- `sent`: 申请已发送
- `outgoing_pending`: 你已发过申请，对方还未处理
- `incoming_pending`: 对方已向你发送申请，请直接处理对方申请
- `already_friends`: 双方已经是好友
- `self`: 不能给自己发送好友申请

**成功发送示例:**

```json
{
  "success": true,
  "status": "sent",
  "message": "好友申请已发送",
  "requestId": 1
}
```

**提示型响应示例（不会抛异常，前端需按 `status` 判断提示）:**

```json
{
  "success": false,
  "status": "incoming_pending",
  "message": "对方已向你发送好友申请，请直接处理对方申请"
}
```

### 3. 获取好友申请列表

**端点:** `GET /friends/requests`

**查询参数:**

- `page` (number, 可选): 页码，默认 1
- `pageSize` (number, 可选): 每页数量，默认 20
- `status` (string, 可选): 申请状态 (pending/accepted/rejected/expired)

**响应:**

```json
{
  "data": [
    {
      "id": 1,
      "requesterId": 2,
      "requesterName": "李四",
      "requesterAvatar": "https://example.com/avatar.jpg",
      "requesterPhone": "13800138001",
      "message": "你好，我是李四",
      "status": "pending",
      "rejectionReason": null,
      "expiresAt": "2025-02-09T00:00:00.000Z",
      "createdAt": "2025-02-02T00:00:00.000Z"
    }
  ],
  "total": 1,
  "page": 1,
  "pageSize": 20
}
```

### 4. 接受好友申请

**端点:** `POST /friends/requests/:id/accept`

**响应:**

```json
{
  "success": true,
  "data": {
    "friendRequest": {
      /* 申请信息 */
    },
    "friendship": {
      /* 好友关系 */
    }
  }
}
```

### 5. 拒绝好友申请

**端点:** `POST /friends/requests/:id/reject`

**请求体:** 无需请求体

> NOTE: 历史版本客户端即使仍传 `reason` 字段，服务端也会兼容处理，但当前接口已不再要求提供拒绝原因。

**响应:**

```json
{
  "success": true
}
```

### 6. 获取好友列表

**端点:** `GET /friends`

**查询参数:**

- `page` (number, 可选): 页码，默认 1
- `pageSize` (number, 可选): 每页数量，默认 20
- `search` (string, 可选): 搜索关键词（昵称/备注）

**响应:**

```json
{
  "data": [
    {
      "id": 1,
      "userId": 1,
      "friendId": 2,
      "friendName": "李四",
      "friendAvatar": "https://example.com/avatar.jpg",
      "friendPhone": "13800138001",
      "remark": "同事",
      "direction": "sent",
      "lastChatAt": "2025-02-02T10:00:00.000Z",
      "createdAt": "2025-02-01T00:00:00.000Z"
    }
  ],
  "total": 1,
  "page": 1,
  "pageSize": 20
}
```

当用户没有好友（或搜索结果为空）时，接口返回正常的空分页结果，不会返回业务错误：

```json
{
  "data": [],
  "total": 0,
  "page": 1,
  "pageSize": 20,
  "totalPages": 0
}
```

### 7. 获取好友关系摘要

**端点:** `GET /friends/relationship/:targetUserId`

**响应:**

```json
{
  "isFriend": true,
  "outgoingPending": false,
  "incomingPending": false,
  "blockedByMe": false,
  "canSendMessage": true
}
```

- `blockedByMe`：当前用户是否在好友聊天中拉黑了目标用户
- `canSendMessage`：双方当前仍是好友，并且任一方都没有拉黑对方时为 `true`

### 8. 拉黑好友聊天

**端点:** `POST /friends/chat-blocks`

**请求体:**

```json
{
  "blockedUserId": 2
}
```

仅允许拉黑当前好友；重复拉黑按幂等成功处理。此操作不会删除好友关系，也不会影响社区、活动、走失 / 领养或二手商品等模块的内容展示。

**响应:**

```json
{
  "success": true,
  "data": {
    "id": 1,
    "blockedUserId": 2,
    "blockedAt": "2026-07-27T08:00:00.000Z"
  }
}
```

### 9. 获取好友聊天黑名单

**端点:** `GET /friends/chat-blocks`

**查询参数:**

- `page` (number, 可选): 页码，默认 1
- `pageSize` (number, 可选): 每页数量，默认 20，最大 100

**响应:**

```json
{
  "data": [
    {
      "id": 1,
      "blockedUserId": 2,
      "blockedAt": "2026-07-27T08:00:00.000Z",
      "blockedUser": {
        "id": 2,
        "username": "李四",
        "avatar": "https://example.com/avatar.jpg"
      }
    }
  ],
  "total": 1,
  "page": 1,
  "pageSize": 20,
  "totalPages": 1
}
```

黑名单记录独立于好友关系保存。因此，对方删除好友后，该用户仍会显示在当前用户的黑名单中，直到当前用户主动解除拉黑。

### 10. 解除好友聊天拉黑

**端点:** `DELETE /friends/chat-blocks/:blockedUserId`

即使双方已经不是好友，也允许解除拉黑；重复解除按成功处理。解除拉黑不会自动恢复好友关系。

**响应:**

```json
{
  "success": true
}
```

### 11. 修改好友备注

**端点:** `PUT /friends/:friendId/remark`

**请求体:**

```json
{
  "remark": "同事（技术部）"
}
```

**响应:**

```json
{
  "success": true
}
```

### 12. 删除好友

**端点:** `DELETE /friends/:friendId`

**响应:**

```json
{
  "success": true
}
```

### 13. 发送消息（HTTP 备用接口）

**端点:** `POST /friends/messages/send`

**请求体:**

```json
{
  "receiverId": 2,
  "messageType": "text",
  "content": "你好"
}
```

**响应:**

```json
{
  "success": true,
  "data": {
    "message": {
      "id": 1,
      "messageId": "uuid-string",
      "conversationId": "1_2",
      "senderId": 1,
      "receiverId": 2,
      "messageType": "text",
      "content": "你好",
      "cloudFileUrl": null,
      "isRead": 0,
      "createdAt": "2025-02-02T10:00:00.000Z"
    }
  }
}
```

### 14. 获取历史消息

**端点:** `GET /friends/messages/:friendId/history`

**查询参数:**

- `page` (number, 可选): 页码，默认 1
- `pageSize` (number, 可选): 每页数量，默认 50

**响应:**

```json
{
  "data": [
    {
      "id": 1,
      "messageId": "uuid-string",
      "conversationId": "1_2",
      "senderId": 1,
      "receiverId": 2,
      "messageType": "text",
      "content": "你好",
      "cloudFileUrl": null,
      "isRead": 1,
      "createdAt": "2025-02-02T10:00:00.000Z"
    }
  ],
  "total": 1,
  "page": 1,
  "pageSize": 50
}
```

### 15. Admin - 获取统计数据

**端点:** `GET /friends/admin/statistics`

**响应:**

```json
{
  "success": true,
  "data": {
    "totalFriendships": 100,
    "todayNewFriendships": 5,
    "activeUsers": 50,
    "totalMessages": 1000,
    "todayMessages": 100,
    "pendingRequests": 10,
    "offlineQueueSize": 20,
    "avgFriendsPerUser": 10.5,
    "messageStatsByType": {
      "text": 800,
      "image": 150,
      "voice": 50
    }
  }
}
```

### TypeScript 类型定义

```typescript
/**
 * 好友关系
 */
interface Friendship {
  id: number
  userId: number
  friendId: number
  friendName: string
  friendAvatar: string
  friendPhone: string
  remark: string | null
  direction: 'sent' | 'received'
  lastChatAt: string | null
  createdAt: string
}

/**
 * 好友申请
 */
interface FriendRequest {
  id: number
  requesterId: number
  requesterName: string
  requesterAvatar: string
  requesterPhone: string
  message: string | null
  status: 'pending' | 'accepted' | 'rejected' | 'expired'
  rejectionReason: string | null
  expiresAt: string
  createdAt: string
}

/**
 * 好友消息
 */
interface FriendMessage {
  id: number
  messageId: string
  conversationId: string
  senderId: number
  receiverId: number
  messageType: 'text' | 'image' | 'voice'
  content: string
  cloudFileUrl: string | null
  isRead: number
  createdAt: string
}

/**
 * 好友聊天黑名单记录
 */
interface FriendChatBlock {
  id: number
  blockedUserId: number
  blockedAt: string
  blockedUser: {
    id: number
    username: string | null
    avatar: string | null
  }
}
```

### 前端调用示例

```typescript
import {
  searchUserByPhoneApi,
  sendFriendRequestApi,
  getFriendRequestsApi,
  acceptFriendRequestApi,
  rejectFriendRequestApi,
  getFriendsListApi,
  updateFriendRemarkApi,
  deleteFriendApi,
  sendMessageApi,
  getHistoryMessagesApi
} from '@/api-new/friends'

// 搜索用户
const searchUser = async (phone: string) => {
  const res = await searchUserByPhoneApi({ phone })
  if (res.success) {
    console.log('找到用户:', res.data)
  }
}

// 发送好友申请
const sendRequest = async (receiverId: number, message: string) => {
  const res = await sendFriendRequestApi({ receiverId, message })
  if (res.status === 'sent') {
    console.log('申请已发送')
    return
  }

  console.log('提示型结果:', res.status, res.message)
}

// 获取好友列表
const getFriends = async () => {
  const res = await getFriendsListApi({ page: 1, pageSize: 20 })
  console.log('好友列表:', res.data)
  console.log('总数:', res.total)
}
```

### 注意事项

1. **好友关系是双向的**：添加好友时会创建两条记录（A→B 和 B→A）
2. **好友申请有效期**：申请有效期为 7 天，过期后自动标记为 expired
3. **提示型结果不走异常**：像“对方已向你发送申请”“已经是好友”这类场景会返回 HTTP 200，前端应通过 `status` 分支处理
4. **消息永久保存**：MySQL 中的消息记录永久保存，供 Admin 审计
5. **离线消息队列**：Redis 中的离线消息 TTL 为 30 天
6. **云端文件清理**：图片/语音文件 30 天后自动清理
7. **WebSocket 命名空间**：使用独立的 `/friends` 命名空间
8. **多设备支持**：同一用户可以在多个设备同时在线
9. **好友聊天拉黑是独立状态**：只影响好友申请、好友消息和输入状态，不复用 Moderation 模块的全局内容屏蔽
10. **拉黑不删除好友**：拉黑后双方仍保留好友关系，但任一方向均不能发送好友消息
11. **删除好友不删除拉黑记录**：A 拉黑 B 后，即使 B 删除 A，A 的黑名单记录仍保留
12. **解除拉黑不恢复好友**：上述场景中 A 解除 B 后，双方仍不是好友，A 发消息会因好友关系不存在而被拒绝
13. **重新加好友受限**：任一方存在好友聊天拉黑记录时，不能发送或接受双方之间的好友申请
14. **生产环境需要迁移**：部署新版本前执行 `cd server && npx ts-node migrations/add-friend-chat-blocks.ts`；脚本可重复执行，已有表时会自动跳过

---

## Marketplace Chat 模块

二手商城买家与卖家的商品级会话。每个“商品 + 买家 + 卖家”最多创建一个会话；买卖双方都能在消息中心查看并继续沟通。

### HTTP 接口

所有接口均需用户 JWT。

| HTTP 方法 | 路径 | 描述 | 权限 |
| --- | --- | --- | --- |
| POST | /marketplace-chat/conversations | 创建或获取商品会话 | ✅ |
| GET | /marketplace-chat/conversations | 分页获取当前用户会话 | ✅ |
| GET | /marketplace-chat/conversations/:conversationId | 获取会话详情 | ✅ |
| GET | /marketplace-chat/conversations/:conversationId/messages | 分页获取历史消息 | ✅ |
| POST | /marketplace-chat/messages/send | 发送消息（HTTP 备用） | ✅ |
| POST | /marketplace-chat/messages/:messageId/revoke | 撤回本人 2 分钟内发送的消息 | ✅ |
| POST | /marketplace-chat/messages/read | 标记单条消息已读 | ✅ |
| POST | /marketplace-chat/conversations/:conversationId/read | 标记整个会话已读 | ✅ |
| GET | /marketplace-chat/unread-count | 获取商城消息未读总数 | ✅ |

### 创建或获取商品会话

**端点:** `POST /marketplace-chat/conversations`

```json
{
  "productId": 20
}
```

仅用户发布的二手商品可以创建新会话。不能联系自己；商品已下架、售罄或已售出时不允许新建会话，但已存在的买卖会话仍可继续查看和沟通。

```json
{
  "success": true,
  "data": {
    "conversationId": "07b2cb4a-fc43-42cb-941f-6a05c09fc33e",
    "productId": 20,
    "buyerId": 3,
    "sellerId": 9,
    "role": "buyer",
    "peer": {
      "id": 9,
      "nickname": "卖家昵称",
      "username": "seller",
      "avatar": "/uploads/avatar.jpg"
    },
    "product": {
      "id": 20,
      "name": "闲置猫包",
      "image": "/uploads/cat-bag.jpg",
      "price": 88,
      "isActive": true,
      "isSold": false
    },
    "lastMessage": null,
    "unreadCount": 0,
    "createdAt": "2026-07-27T08:00:00.000Z",
    "updatedAt": "2026-07-27T08:00:00.000Z"
  }
}
```

### 会话和消息分页

会话列表支持 `page`、`pageSize`，默认分别为 `1`、`20`；消息历史默认 `pageSize=50`，最大均为 `100`。消息按创建时间倒序返回。

```json
{
  "data": [],
  "total": 0,
  "page": 1,
  "pageSize": 20,
  "totalPages": 0
}
```

### HTTP 发送消息

**端点:** `POST /marketplace-chat/messages/send`

```json
{
  "conversationId": "07b2cb4a-fc43-42cb-941f-6a05c09fc33e",
  "messageType": "text",
  "content": "请问还在吗？",
  "tempMessageId": "marketplace_3_1722067200000"
}
```

`messageType` 支持 `text`、`image`、`voice`、`video`。媒体消息的 `content` 使用 JSON 字符串，字段约定与 Friends 模块一致。

### WebSocket 事件

**命名空间:** `/marketplace-chat`

**客户端 → 服务器:**

- `marketplace:join` - 加入当前用户房间
- `marketplace:message:send` - 发送消息，载荷与 HTTP 发送接口一致
- `marketplace:message:revoke` - 撤回本人 2 分钟内发送的消息，载荷为 `{"messageId":"..."}`
- `marketplace:message:read` - 标记单条消息已读
- `marketplace:typing:start` - 开始输入
- `marketplace:typing:stop` - 停止输入
- `marketplace:offline:fetch` - 主动拉取离线消息
- `marketplace:offline:ack` - 确认离线消息已持久化，载荷为 `{"messageIds":["..."]}`

**服务器 → 客户端:**

- `marketplace:message:new` - 新消息或离线消息
- `marketplace:message:revoked` - 消息撤回通知，载荷为撤回后的消息对象
- `marketplace:message:ack` - 消息发送确认
- `marketplace:read:receipt` - 已读回执
- `marketplace:typing:indicator` - 对方输入状态
- `auth:session:revoked` - 登录会话失效

离线消息附带 `deliveryMode: "offline"`。客户端本地落库后再发送 `marketplace:offline:ack`，服务端收到确认后才从 Redis 删除；离线队列 TTL 为 30 天。

### 权限与治理

- 服务端校验会话参与者，非买家或卖家不能读取、发送或修改该会话消息。
- 创建会话及发送消息都会复用用户屏蔽关系校验。
- 举报商城消息使用 Moderation 接口，`targetType` 为 `MARKETPLACE_MESSAGE`，`targetId` 为消息 UUID。
- 消息永久保存在 MySQL；图片、语音和视频继续复用现有上传服务与媒体 JSON 格式。
- 撤回仅允许发送者在服务端时间 2 分钟内操作；普通客户端与离线队列只收到文本占位，最近消息摘要同步更新为“消息已撤回”。

### 部署迁移

部署新服务版本前，在 `server` 目录执行：

```bash
ts-node migrations/add-marketplace-chat.ts
```

迁移会创建 `marketplace_conversations`、`marketplace_messages`，并为 `ugc_reports.targetType` 增加 `MARKETPLACE_MESSAGE`。脚本可重复运行，已有表和枚举值不会重复创建。

消息撤回字段请额外执行：

```bash
ts-node migrations/add-chat-message-recall.ts
```

该脚本为 `friend_messages`、`marketplace_messages` 和 `messages` 补齐 `isRevoked`、`revokedAt` 字段，可重复执行。

---

## Notifications 模块

站内通知模块，供 rnapp 通知中心读取用户通知、未读数量和已读状态。

### 标准成功响应

通知接口遵循统一成功包裹格式：

```json
{
  "code": 0,
  "data": {},
  "message": "Success",
  "pagination": {
    "total": 20,
    "page": 1,
    "totalPages": 1
  }
}
```

### 分页字段说明

- 分页接口会在最外层返回 `pagination`
- `pagination.total` 表示总条数
- `pagination.page` 表示当前页
- `pagination.totalPages` 表示总页数
- 页大小请以前端请求参数 `pageSize` 为准；若运行时额外出现 `limit` 字段，可视为 `pageSize` 的同义字段

### 通知跳转协议

`actionType` 和 `actionData` 必须成对使用。新通知支持以下目标：

| 目标 | actionType | actionData |
| ---- | ---------- | ---------- |
| 订单详情 | `order` | `{ "orderId": 123 }` |
| 普通预约详情 | `appointment` | `{ "appointmentId": 123, "appointmentKind": "standard" }` |
| 健康预约详情 | `appointment` | `{ "appointmentId": 123, "appointmentKind": "health" }` |
| App 页面 | `page` | `{ "path": "PostDetail", "params": { "postId": 123 } }` |
| 外部网页 | `url` | `{ "url": "https://example.com" }` |

`page.path` 可使用 `Home`、`PetList`、`OrderList`、`MedicalServiceOrderList`、`AddressList`、`Notifications`、`CommunityProfile`、`MyCoupons`、`MyFavorites`、`MyPublishedProducts`、`SystemConfig`、`SecuritySettings`、`MyIncome`、`OrderDetail`、`ProductDetail`、`PostDetail`、`UserProfile` 和 `Chat`。`PostDetail` 使用 `params.postId`，`UserProfile` 使用 `params.userId`，`Chat` 使用 `params.conversationId`。

### 接口总览

| HTTP 方法 | 路径                        | 描述                 | 权限    |
| --------- | --------------------------- | -------------------- | ------- |
| GET       | /notifications              | 获取通知列表（分页） | ✅ USER |
| GET       | /notifications/unread-count | 获取未读通知数量     | ✅ USER |
| GET       | /notifications/:id          | 获取通知详情         | ✅ USER |
| PUT       | /notifications/:id/read     | 标记单条通知已读     | ✅ USER |
| PUT       | /notifications/read-all     | 标记全部通知已读     | ✅ USER |

### 获取通知列表

**端点:** `GET /notifications`

**查询参数:**

| 参数     | 类型                                        | 必填 | 说明              |
| -------- | ------------------------------------------- | ---- | ----------------- |
| page     | number                                      | 否   | 页码，默认 1      |
| pageSize | number                                      | 否   | 每页数量，默认 20 |
| type     | `system` \| `announcement` \| `interaction` | 否   | 按通知类型筛选    |

**响应示例:**

```json
{
  "code": 0,
  "data": [
    {
      "id": 101,
      "userId": 8,
      "type": "announcement",
      "title": "公益活动回顾已发布",
      "content": "你参与的公益活动已发布总结文章，点击查看详情。",
      "isRead": false,
      "actionType": "page",
      "actionData": {
        "path": "PostDetail",
        "params": { "postId": 12 }
      },
      "priority": 0,
      "createdAt": 1770201000000,
      "updatedAt": 1770201000000,
      "readAt": null
    }
  ],
  "message": "Success",
  "pagination": {
    "total": 32,
    "page": 1,
    "totalPages": 2
  }
}
```

### 获取未读通知数量

**端点:** `GET /notifications/unread-count`

**响应示例:**

```json
{
  "code": 0,
  "data": {
    "count": 5
  },
  "message": "Success"
}
```

**常见错误响应:**

`GET /notifications/unread-count` 当前错误响应由 `HttpExceptionFilter` 统一输出，HTTP 状态码固定为 `200`，前端应根据响应体内的 `success=false` 与 `statusCode=401` 判定失败。该 401 结构已通过通知模块响应契约回归测试覆盖。

```json
{
  "success": false,
  "code": 401,
  "statusCode": 401,
  "timestamp": "2026-03-11T08:00:00.000Z",
  "path": "/notifications/unread-count",
  "method": "GET",
  "message": "Unauthorized",
  "error": "UnauthorizedException"
}
```

### 获取通知详情

**端点:** `GET /notifications/:id`

**响应示例:**

```json
{
  "code": 0,
  "data": {
    "id": 101,
    "userId": 8,
    "type": "announcement",
    "title": "公益活动回顾已发布",
    "content": "你参与的公益活动已发布总结文章，点击查看详情。",
    "isRead": true,
    "actionType": "page",
    "actionData": {
      "path": "PostDetail",
      "params": { "postId": 12 }
    },
    "priority": 0,
    "createdAt": 1770201000000,
    "updatedAt": 1770201200000,
    "readAt": 1770201200000
  },
  "message": "Success"
}
```

### 标记已读

**端点:**

- `PUT /notifications/:id/read`
- `PUT /notifications/read-all`

**说明:** 这两个操作态接口会先走统一成功包裹，再把后端业务载荷完整保留在最外层 `data` 中；rnapp 不应把它们误判为“直接返回布尔值”。

**单条已读响应示例:**

```json
{
  "code": 0,
  "data": {
    "success": true
  },
  "message": "Success"
}
```

**单条已读常见错误响应:**

- 未登录：由 `HttpExceptionFilter` 输出 HTTP 200 + `statusCode=401`（已通过通知模块响应契约回归测试覆盖）
- 通知不存在：由 `HttpExceptionFilter` 输出 HTTP 200 + `statusCode=404`

```json
{
  "success": false,
  "code": 401,
  "statusCode": 401,
  "timestamp": "2026-03-11T08:00:00.000Z",
  "path": "/notifications/1/read",
  "method": "PUT",
  "message": "Unauthorized",
  "error": "UnauthorizedException"
}
```

```json
{
  "success": false,
  "code": 404,
  "statusCode": 404,
  "timestamp": "2026-03-11T08:00:00.000Z",
  "path": "/notifications/999/read",
  "method": "PUT",
  "message": "Notification not found",
  "error": "Not Found"
}
```

**全部已读响应示例:**

```json
{
  "code": 0,
  "data": {
    "success": true,
    "updatedCount": 5
  },
  "message": "Success"
}
```

**全部已读常见错误响应:**

`PUT /notifications/read-all` 当前错误响应由 `HttpExceptionFilter` 统一输出，HTTP 状态码固定为 `200`。该 401 结构已通过通知模块响应契约回归测试覆盖。

```json
{
  "success": false,
  "code": 401,
  "statusCode": 401,
  "timestamp": "2026-03-11T08:00:00.000Z",
  "path": "/notifications/read-all",
  "method": "PUT",
  "message": "Unauthorized",
  "error": "UnauthorizedException"
}
```

> NOTE: `PUT /notifications/:id/read` 的内层业务载荷为 `{ success: true }`；`PUT /notifications/read-all` 的内层业务载荷为 `{ success: true, updatedCount }`。

---

## Charity 模块

公益管理模块，支持签到打卡、任务完成、爱心捐款等公益类型的管理。

### 数据类型定义

```typescript
/**
 * 公益状态
 */
enum CharityStatus {
  DRAFT = 'DRAFT', // 草稿
  ACTIVE = 'ACTIVE', // 进行中
  EXPIRED = 'EXPIRED' // 已结束
}

/**
 * 参与类型
 */
enum ParticipantType {
  CHECKIN = 'checkin', // 签到打卡
  TASK = 'task', // 任务完成
  DONATION = 'donation' // 爱心捐款
}

/**
 * 公益实体
 */
interface Charity {
  id: number
  title: string // 公益名称
  description: string // 公益描述
  details?: string // 公益详情（富文本内容）
  coverImage?: string // 封面图片
  startTime?: string // 开始时间（商城自动公益固定为空）
  endTime?: string // 结束时间（商城自动公益固定为空）
  targetCheckIns: number // 目标打卡数（捐款类型固定为 0）
  completedCheckIns: number // 已完成打卡次数（所有参与者的打卡次数总和）
  donatedAmount?: number // 已捐金额（捐款类型返回）
  participantType: ParticipantType // 参与类型
  isMallAutoDonation: boolean // 是否为商城自动公益活动
  donationRate: number // 自动公益比例，百分比语义，1.5 表示订单实付金额的 1.5%
  isPinned: boolean // 是否置顶展示
  taskConfig?: Record<string, any> // 任务配置
  status: CharityStatus // 公益状态
  participantCount?: number // 参与人数
  userCheckInCount?: number // 当前用户打卡次数（仅用户端）
  hasCheckedToday?: boolean // 今日是否已打卡（仅用户端）
  createdAt: string
  updatedAt: string
}

/**
 * 签到记录
 */
interface CharityRecord {
  id: number
  charityId: number
  userId: number
  checkInDate: string // 签到日期 (YYYY-MM-DD)
  checkInTime: string // 签到时间
  taskType?: string // 任务类型
  taskEvidence?: string // 任务凭证
  donationAmount?: number // 捐款金额（捐款类型专用）
  donationSource?: 'manual' | 'mall_order' // 捐款来源：主动捐款 / 商城订单
  donationEntryType?: 'credit' | 'reversal' // 流水类型：入账 / 退款冲销
  orderId?: number // 商城订单 ID（商城订单流水专用）
  orderNo?: string // 商城订单号（商城订单流水专用）
  donationBaseAmount?: number // 计算基数：订单实付金额或退款金额
  donationRate?: number // 入账时的公益比例快照，百分比语义
  sourceReference?: string // 流水幂等标识
  createdAt: string
}

/**
 * 公益文章
 */
interface CharityArticle {
  id: number
  charityId: number
  title: string
  content: string
  publisherId: number
  targetUserIds?: number[] // 目标用户ID列表
  sendNotification: boolean
  isPublished: boolean
  createdAt: string
}
```

---

### 用户端接口

#### 1. 获取公益列表

- **接口**: `GET /charity`
- **权限**: 🌐 匿名可访问，可选携带 JWT
- **说明**:
  - 打卡类型：携带用户 token 时，会额外返回 `userCheckInCount`、`hasCheckedToday`
  - 捐款类型：会额外返回 `donatedAmount`
  - 用户端仅返回未删除公益，已软删除数据不会展示
  - 按 `isPinned` 降序、创建时间降序排序；商城自动公益活动固定置顶
- **查询参数**:

| 参数     | 类型              | 必填 | 说明               |
| -------- | ----------------- | ---- | ------------------ |
| status   | ACTIVE \| EXPIRED | 否   | 状态筛选           |
| keyword  | string            | 否   | 按公益名称模糊搜索 |
| page     | number            | 否   | 页码，默认 1       |
| pageSize | number            | 否   | 每页数量，默认 10  |

**响应示例**:

```json
{
  "code": 0,
  "data": [
    {
      "id": 1,
      "title": "7天健康打卡",
      "description": "连续打卡7天，培养健康习惯",
      "details": "<p>每天完成一次遛宠并上传照片。</p>",
      "coverImage": "/uploads/activity1.jpg",
      "startTime": "2026-02-01T00:00:00.000Z",
      "endTime": "2026-02-28T23:59:59.000Z",
      "targetCheckIns": 7,
      "completedCheckIns": 56,
      "participantType": "checkin",
      "status": "ACTIVE"
    },
    {
      "id": 2,
      "title": "流浪动物医疗募捐",
      "description": "为流浪动物筹集医疗费用",
      "coverImage": "/uploads/activity2.jpg",
      "startTime": "2026-02-01T00:00:00.000Z",
      "endTime": "2026-02-28T23:59:59.000Z",
      "targetCheckIns": 0,
      "completedCheckIns": 0,
      "participantType": "donation",
      "donatedAmount": 5200.5,
      "status": "ACTIVE"
    }
  ],
  "message": "Success",
  "pagination": {
    "total": 10,
    "page": 1,
    "pageSize": 10,
    "totalPages": 1
  }
}
```

---

#### 2. 获取公益详情

- **接口**: `GET \/charity\/:id`
- **权限**: 🌐 匿名可访问，可选携带 JWT
- **说明**:
  - 打卡类型：携带用户 token 时，会额外返回 `userCheckInCount`、`hasCheckedToday`
  - 捐款类型：会额外返回 `donatedAmount`
- **路径参数**:

| 参数 | 类型   | 必填 | 说明    |
| ---- | ------ | ---- | ------- |
| id   | number | 是   | 公益 ID |

**响应示例**:

```json
{
  "code": 0,
  "data": {
    "id": 12,
    "title": "7天健康打卡",
    "description": "连续打卡7天，培养健康习惯",
    "details": "<p>每天完成一次遛宠并上传照片。</p>",
    "coverImage": "/uploads/activity1.jpg",
    "startTime": "2026-02-01T00:00:00.000Z",
    "endTime": "2026-02-28T23:59:59.000Z",
    "targetCheckIns": 7,
    "completedCheckIns": 56,
    "participantType": "checkin",
    "status": "ACTIVE",
    "userCheckInCount": 3,
    "hasCheckedToday": false
  },
  "message": "Success"
}
```

**捐款类型详情示例**:

```json
{
  "code": 0,
  "data": {
    "id": 21,
    "title": "流浪动物医疗募捐",
    "description": "为流浪动物筹集医疗费用",
    "coverImage": "/uploads/activity2.jpg",
    "startTime": "2026-02-01T00:00:00.000Z",
    "endTime": "2026-02-28T23:59:59.000Z",
    "targetCheckIns": 0,
    "completedCheckIns": 0,
    "participantType": "donation",
    "donatedAmount": 5200.5,
    "status": "ACTIVE"
  },
  "message": "Success"
}
```

---

#### 3. 签到/完成任务

- **接口**: `POST \/charity\/:id/checkin`
- **权限**: ✅ 需要登录
- **请求体**:

```json
{
  "taskType": "share",
  "taskEvidence": "https://example.com/share.png"
}
```

**字段说明**: | 字段 | 类型 | 必填 | 说明 | |------|------|------|------| | taskType | string | 否 | 任务类型（仅任务型公益需要） | | taskEvidence | string | 否 | 任务凭证（图片 URL） |

**响应示例**:

```json
{
  "code": 0,
  "data": {
    "success": true,
    "totalCheckIns": 4,
    "message": "签到成功",
    "isCompleted": false
  },
  "message": "签到成功"
}
```

**已打卡响应示例:**

```json
{
  "code": 0,
  "data": {
    "success": false,
    "alreadyChecked": true,
    "totalCheckIns": 4,
    "message": "您今天已经打过卡了，明天再来吧！",
    "isCompleted": false
  },
  "message": "您今天已经打过卡了，明天再来吧！"
}
```

> NOTE: `POST /charity/:id/checkin` 不会把业务字段拍平到最外层；当前后端会保留内层 `success/message/...` 业务载荷，同时把最外层 `message` 设为同一条业务消息。

> NOTE: `participantType=donation` 的公益不支持调用该接口，前端应隐藏签到入口。

**常见错误响应:**

- 未登录、非法 JWT、过期 JWT：由 `HttpExceptionFilter` 输出 HTTP 200 + `statusCode=401`（无 token 与真实 JwtAuthGuard 轻量集成、契约测试均已覆盖）
- token 签名合法但用户已失效：仍返回 HTTP 200 + `statusCode=401`，但 `message` 会变为“用户不存在”，且 `error` 字段为 `Unauthorized`
- 公益不存在：由 `BusinessExceptionFilter` 输出 HTTP 200 + `statusCode=400` 业务错误

```json
{
  "success": false,
  "code": 401,
  "statusCode": 401,
  "timestamp": "2026-03-11T08:00:00.000Z",
  "path": "/charity/1/checkin",
  "method": "POST",
  "message": "Unauthorized",
  "error": "UnauthorizedException"
}
```

```json
{
  "success": false,
  "code": 401,
  "statusCode": 401,
  "timestamp": "2026-03-11T08:00:00.000Z",
  "path": "/charity/1/checkin",
  "method": "POST",
  "message": "用户不存在",
  "error": "Unauthorized"
}
```

```json
{
  "success": false,
  "statusCode": 400,
  "message": "公益不存在",
  "code": "3301",
  "error": "BUSINESS_ERROR",
  "timestamp": "2026-03-11T08:00:00.000Z",
  "path": "/charity/999/checkin",
  "method": "POST"
}
```

---

#### 首页公告：获取最新捐赠记录

- **接口**: `GET /charity/latest-donations`
- **权限**: 🌐 可匿名访问，可选 JWT
- **参数**: 无，固定读取最近 20 笔正向捐款流水，按 `checkInTime DESC, id DESC` 排序。
- **筛选**: `taskType` 为 `donation`（主动捐款）或 `mall_order`（订单公益）、`donationAmount>0` 且 `donationEntryType=credit`；退款冲销不作为新捐赠播报。返回历史正向流水金额，不是扣除退款后的累计净额。
- **隐私**: 仅返回展示所需字段，不返回 `userId` 或手机号；昵称中的手机号脱敏，昵称缺失或用户不存在时显示“爱心人士”。
- **来源**: `donationSource=mall_order` 为商城订单自动公益，`manual` 为主动捐款（余额或支付宝）。

**响应示例**:

```json
{
  "code": 0,
  "data": [
    {
      "id": 91,
      "charityId": 12,
      "userName": "爱心人士",
      "checkInTime": "2026-09-05T08:30:00.000Z",
      "donationAmount": 20.5,
      "donationSource": "mall_order",
      "createdAt": "2026-09-05T08:30:00.000Z"
    }
  ],
  "message": "Success",
  "pagination": {
    "total": 1,
    "page": 1,
    "pageSize": 20,
    "limit": 20,
    "totalPages": 1
  }
}
```

无捐赠时 `data=[]`、`pagination.total=0`、`pagination.totalPages=0`。此接口不改变现有捐款明细、参与者查询或退款冲销逻辑。

---

#### 4. 获取签到记录

- **接口**: `GET \/charity\/:id/records`
- **权限**: ✅ 需要登录
- **说明**: `participantType=donation` 时当前接口返回空列表，捐款明细请使用 `GET /charity/:id/donations`
- **查询参数**:

| 参数     | 类型   | 必填 | 说明              |
| -------- | ------ | ---- | ----------------- |
| page     | number | 否   | 页码，默认 1      |
| pageSize | number | 否   | 每页数量，默认 10 |

**响应示例**:

```json
{
  "code": 0,
  "data": [
    {
      "id": 91,
      "charityId": 12,
      "userId": 8,
      "checkInDate": "2026-03-11",
      "checkInTime": "2026-03-11T08:30:00.000Z",
      "taskType": "checkin",
      "taskEvidence": null,
      "createdAt": "2026-03-11T08:30:00.000Z"
    }
  ],
  "message": "Success",
  "pagination": {
    "total": 3,
    "page": 1,
    "pageSize": 10,
    "limit": 10,
    "totalPages": 1
  }
}
```

**常见错误响应:**

- 未登录：由 `HttpExceptionFilter` 输出 HTTP 200 + `statusCode=401`（已通过响应契约回归测试覆盖）
- 公益不存在：由 `BusinessExceptionFilter` 输出 HTTP 200 + `statusCode=400` 业务错误

```json
{
  "success": false,
  "code": 401,
  "statusCode": 401,
  "timestamp": "2026-03-11T08:00:00.000Z",
  "path": "/charity/1/records",
  "method": "GET",
  "message": "Unauthorized",
  "error": "UnauthorizedException"
}
```

```json
{
  "success": false,
  "statusCode": 400,
  "message": "公益不存在",
  "code": "3301",
  "error": "BUSINESS_ERROR",
  "timestamp": "2026-03-11T08:00:00.000Z",
  "path": "/charity/999/records",
  "method": "GET"
}
```

---

#### 5. 爱心捐款

- **接口**: `POST \/charity\/:id\/donate`
- **权限**: ✅ 需要登录
- **说明**:
  - 当前仅支持余额支付
  - `paymentMethod=online` 仅预留入口，后端会返回“微信/支付宝支付暂未开放，请使用余额支付”
  - `isMallAutoDonation=true` 的活动不支持主动捐款；该类活动仅由商城订单支付和退款自动生成流水
- **请求体**:

```json
{
  "amount": 20.5,
  "paymentMethod": "balance"
}
```

**字段说明**: | 字段 | 类型 | 必填 | 说明 | |------|------|------|------| | amount | number | 是 | 捐款金额，最小 0.01 | | paymentMethod | string | 否 | 支付方式：`balance` / `online`，当前仅支持 `balance` |

**响应示例**:

```json
{
  "code": 0,
  "data": {
    "success": true,
    "message": "捐款成功",
    "donationAmount": 20.5,
    "donatedAmount": 540.5,
    "balanceBefore": 100,
    "balanceAfter": 79.5
  },
  "message": "捐款成功"
}
```

---

#### 5.1 创建支付宝捐款支付单

- **接口**: `POST \/charity\/:id\/donations\/payment`
- **权限**: ✅ 需要登录
- **请求头**: `idempotency-key: <UUID v4>`，同一笔客户端支付尝试必须复用同一值
- **说明**:
  - 仅支持 `participantType=donation` 且状态为 `ACTIVE` 的公益项目
  - `isMallAutoDonation=true` 的活动不支持创建主动捐款支付单
  - 金额和公益归属由公益服务校验后创建 `charity_donation` 支付单
  - Flutter 使用返回的 `paymentParams.alipayOrderString` 拉起支付宝 App
  - 支付宝回调或 `GET /payment/query/:paymentNo` 主动查单确认成功后，服务端幂等生成公益捐款记录
- **请求体**:

```json
{
  "amount": 20.5
}
```

**响应示例**:

```json
{
  "code": 0,
  "data": {
    "paymentNo": "PAY202607311234567890",
    "outTradeNo": "charity_6_12_123e4567e89b42d3a456426614174000",
    "amount": 20.5,
    "channel": "alipay",
    "method": "app",
    "paymentParams": {
      "alipayOrderString": "app_id=..."
    },
    "expiredAt": "2026-07-31T10:15:00.000Z"
  }
}
```

客户端拿到支付参数后应调用支付宝 SDK，并通过 `GET /payment/query/:paymentNo` 查询最终状态。只有状态为 `success` 时才展示捐款成功；`pending` 或 `processing` 应提示用户稍后在公益详情确认。

---

#### 6. 获取公益文章

- **接口**: `GET \/charity\/:id/articles`
- **权限**: 🌐 匿名可访问，可选携带 JWT
- **说明**: 携带用户 token 时，仅返回推送给当前用户或全员可见的文章

> NOTE: 该接口面向用户端。管理端查看公益文章列表时，应使用 `GET /charity/admin/:id/articles`，避免携带 admin token 后被 `targetUserIds` 过滤。

**响应示例**:

```json
{
  "code": 0,
  "data": [
    {
      "id": 7,
      "charityId": 12,
      "title": "公益总结",
      "content": "<p>恭喜大家完成公益！</p>",
      "publisherId": 1,
      "targetUserIds": [8, 9, 10],
      "sendNotification": true,
      "isPublished": true,
      "createdAt": "2026-03-01T14:00:00.000Z"
    }
  ],
  "message": "Success"
}
```

**用户态说明**:

- 未登录：返回该公益下所有已发布文章
- 已登录：仅返回 `targetUserIds` 包含当前用户，或 `targetUserIds` 为空/全员可见的文章

---

#### 7. 获取捐款明细

- **接口**: `GET \/charity\/:id\/donations`
- **权限**: 🌐 匿名可访问，可选携带 JWT
- **说明**:
  - 仅捐款型公益支持该接口
  - 返回每一笔捐款或商城自动公益流水，包含捐款人、金额和时间
  - 商城自动公益的退款流水 `donationEntryType=reversal`，`donationAmount` 为负数

**响应示例**:

```json
{
  "code": 0,
  "data": [
    {
      "id": 91,
      "charityId": 12,
      "userId": 8,
      "userName": "张三",
      "userAvatar": "/uploads/avatar1.jpg",
      "checkInDate": null,
      "checkInTime": "2026-03-11T08:30:00.000Z",
      "donationAmount": 20.5,
      "donationSource": "mall_order",
      "donationEntryType": "credit",
      "orderId": 123,
      "orderNo": "ORD202608180001",
      "donationBaseAmount": 100,
      "donationRate": 1.5,
      "createdAt": "2026-03-11T08:30:00.000Z"
    }
  ],
  "message": "Success",
  "pagination": {
    "total": 3,
    "page": 1,
    "pageSize": 10,
    "limit": 10,
    "totalPages": 1
  }
}
```

---

### 管理员接口

> NOTE: 后端当前没有 `GET /charity/admin/:id` 独立详情接口，管理端如需单条详情请复用 `GET /charity/:id` 或列表行数据。

#### 1. 获取公益列表（管理员）

- **接口**: `GET \/charity\/admin/list`
- **权限**: ✅ 需要登录 🎭 SUPER_ADMIN、HOSPITAL_ADMIN、STAFF
- **查询参数**:

| 参数         | 类型   | 必填 | 说明                                                  |
| ------------ | ------ | ---- | ----------------------------------------------------- |
| status       | string | 否   | 公益状态筛选：DRAFT / ACTIVE / EXPIRED               |
| deleteStatus | string | 否   | 删除状态：active=未删除（默认），deleted=已删除，all=全部 |
| keyword      | string | 否   | 关键词搜索                                            |
| page         | number | 否   | 页码，默认 1                                          |
| pageSize     | number | 否   | 每页数量，默认 10                                     |

---

#### 2. 创建公益

- **接口**: `POST \/charity\/admin`
- **权限**: ✅ 需要登录 🎭 SUPER_ADMIN、HOSPITAL_ADMIN、STAFF
- **请求体**:

```json
{
  "title": "7天健康打卡",
  "description": "连续打卡7天，培养健康习惯",
  "details": "<p>每天完成一次遛宠并上传照片。</p>",
  "coverImage": "/uploads/activity1.jpg",
  "startTime": "2026-02-01T00:00:00.000Z",
  "endTime": "2026-02-28T23:59:59.000Z",
  "targetCheckIns": 7,
  "participantType": "checkin",
  "isMallAutoDonation": false,
  "donationRate": 0,
  "isPinned": false,
  "taskConfig": {},
  "status": "ACTIVE"
}
```

**字段说明**: | 字段 | 类型 | 必填 | 说明 | |------|------|------|------| | title | string | 是 | 公益名称 | | description | string | 是 | 公益描述 | | details | string | 否 | 公益详情（富文本内容） | | coverImage | string | 否 | 封面图片 URL | | startTime | string | 否 | 开始时间；商城自动公益会忽略并清空该字段 | | endTime | string | 否 | 结束时间；商城自动公益会忽略并清空该字段 | | targetCheckIns | number | 打卡类型必填 | 目标打卡天数；`participantType=donation` 时固定为 `0` | | participantType | string | 是 | 参与类型：`checkin` / `task` / `donation` | | isMallAutoDonation | boolean | 否 | 是否启用商城自动公益；启用时必须为 `donation` 类型，未删除活动中只允许一个 | | donationRate | number | 自动公益必填 | 百分比比例，范围 `(0, 100]`，例如 `1.5` 表示实付金额的 1.5% | | isPinned | boolean | 否 | 是否置顶；商城自动公益固定置顶 | | taskConfig | object | 否 | 任务配置 | | status | string | 否 | 公益状态：DRAFT / ACTIVE / EXPIRED |

**商城自动公益规则**:

- 未删除的商城自动公益活动只能有一个；重复创建或将其他活动转换为商城自动公益时，接口返回“商城公益活动只能有一个，请编辑现有活动”。
- 商城自动公益不使用开始时间和结束时间，服务端会强制清空这两个字段，是否入账由活动状态控制。
- 订单支付成功后，仅 `OrderType.NORMAL` 普通商品订单参与，二手商品订单不参与。
- 公益金额按订单实付金额计算：`实付金额 × donationRate ÷ 100`，金额按分四舍五入；流水保存比例和计算基数快照。
- 支付履约与公益入账在同一事务内完成，并使用支付单号幂等，重复支付通知不会重复入账。
- 退款成功后按原公益比例生成 `donationEntryType=reversal` 的负数流水；多次退款累计冲销不超过原公益入账金额，退款单号幂等。
- 商城自动公益不开放主动捐款入口；用户端仅展示活动详情和公益流水。

---

#### 3. 更新公益

- **接口**: `PUT \/charity\/admin/:id`
- **权限**: ✅ 需要登录 🎭 SUPER_ADMIN、HOSPITAL_ADMIN、STAFF
- **请求体**: (所有字段可选)
- **说明**: 自动公益字段遵循创建接口规则；已存在商城自动公益时，不允许将其他活动设为商城自动公益。商城自动公益活动始终置顶，且开始时间、结束时间固定为空。

---

#### 4. 删除公益

- **接口**: `DELETE \/charity\/admin/:id`
- **权限**: ✅ 需要登录 🎭 SUPER_ADMIN、HOSPITAL_ADMIN、STAFF
- **说明**: 软删除公益；不再校验是否已有参与者，已有参与记录会保留。可通过列表接口 `deleteStatus=deleted` 或 `deleteStatus=all` 查询已删除数据。

---

#### 5. 获取公益统计

- **接口**: `GET \/charity\/admin/:id/stats`
- **权限**: ✅ 需要登录 🎭 SUPER_ADMIN、HOSPITAL_ADMIN、STAFF
- **响应示例**:

```json
{
  "code": 0,
  "data": {
    "charityId": 1,
    "charityTitle": "7天健康打卡",
    "participantType": "签到打卡",
    "participantCount": 120,
    "targetCheckIns": 7,
    "completedCount": 85,
    "completionRate": 70.83,
    "averageCheckIns": 5.5,
    "totalCheckIns": 660
  }
}
```

**字段说明**: | 字段 | 类型 | 说明 | |------|------|------| | participantCount | number | 参与人数 | | targetCheckIns | number | 目标签到数；捐款类型返回 `0` | | completedCount | number | 已完成人数；捐款类型返回 `0` | | completionRate | number | 完成率 (百分比)；捐款类型返回 `0` | | averageCheckIns | number | 平均签到次数；捐款类型返回 `0` | | totalCheckIns | number | 总签到次数；捐款类型返回 `0` | | donatedAmount | number | 已捐金额，仅捐款类型返回 |

---

#### 6. 获取参与者列表

- **接口**: `GET \/charity\/admin/:id/participants`
- **权限**: ✅ 需要登录 🎭 SUPER_ADMIN、HOSPITAL_ADMIN、STAFF
- **查询参数**:

| 参数     | 类型   | 必填 | 说明              |
| -------- | ------ | ---- | ----------------- |
| page     | number | 否   | 页码，默认 1      |
| pageSize | number | 否   | 每页数量，默认 10 |

**响应示例**:

```json
{
  "code": 0,
  "data": [
    {
      "userId": 1,
      "userName": "张三",
      "userAvatar": "/uploads/avatar1.jpg",
      "checkInCount": 5,
      "firstCheckInTime": "2026-02-01T08:00:00.000Z",
      "lastCheckInTime": "2026-02-05T09:30:00.000Z"
    }
  ],
  "message": "Success",
  "pagination": {
    "total": 18,
    "page": 1,
    "pageSize": 10,
    "totalPages": 2
  }
}
```

**返回结构说明**:

- `userName`、`userAvatar` 来自用户表快照查询
- 打卡类型：
  - `checkInCount` 为当前用户在该公益下的累计打卡次数
  - `firstCheckInTime`、`lastCheckInTime` 为该用户在当前公益下的首末次打卡时间
- 捐款类型：
  - 返回逐笔公益流水，不再按用户聚合；`donationAmount` 为该笔入账或冲销金额
  - `donationSource`、`donationEntryType`、`orderNo`、`donationBaseAmount`、`donationRate` 用于区分来源、退款冲销、订单和计算快照
  - `donationEntryType=reversal` 时 `donationAmount` 为负数

---

#### 7. 发布文章

- **接口**: `POST \/charity\/admin/:id/article`
- **权限**: ✅ 需要登录 🎭 SUPER_ADMIN、HOSPITAL_ADMIN、STAFF
- **业务规则**:
  - **公益必须已结束**（状态为 EXPIRED）
  - **每个公益只能发布一篇文章**
  - `participantType=donation` 的公益不支持文章功能
- **请求体**:

```json
{
  "title": "公益总结",
  "content": "恭喜大家完成公益！",
  "sendNotification": true,
  "targetUserIds": [1, 2, 3]
}
```

**字段说明**: | 字段 | 类型 | 必填 | 说明 | |------|------|------|------| | title | string | 是 | 文章标题 | | content | string | 是 | 文章内容 | | sendNotification | boolean | 否 | 是否发送通知，默认 true | | targetUserIds | number[] | 否 | 目标用户 ID 列表（为空则发送给所有参与者） |

#### 8. 更新文章

- **接口**: `PUT \/charity\/admin/:id/article/:articleId`
- **权限**: ✅ 需要登录 🎭 SUPER_ADMIN、HOSPITAL_ADMIN、STAFF
- **业务规则**: 只能编辑已发布的文章
- **补充说明**: `participantType=donation` 的公益不支持文章功能
- **请求体**:

```json
{
  "title": "公益总结（更新版）",
  "content": "恭喜大家完成公益！这是更新后的内容。",
  "sendNotification": false
}
```

**字段说明**: | 字段 | 类型 | 必填 | 说明 | |------|------|------|------| | title | string | 否 | 文章标题 | | content | string | 否 | 文章内容 | | sendNotification | boolean | 否 | 是否发送通知 |

#### 9. 获取公益已发布的文章

- **接口**: `GET \/charity\/admin/:id/article`
- **权限**: ✅ 需要登录 🎭 SUPER_ADMIN、HOSPITAL_ADMIN、STAFF
- **说明**: 用于编辑时获取已发布的文章内容；若尚未发布文章，`data` 返回 `null`
- **补充说明**: `participantType=donation` 的公益固定返回 `null`

**响应示例**:

```json
{
  "code": 0,
  "data": {
    "id": 1,
    "charityId": 1,
    "title": "公益总结",
    "content": "恭喜大家完成公益！",
    "publisherId": 1,
    "targetUserIds": [1, 2, 3],
    "sendNotification": true,
    "isPublished": true,
    "createdAt": "2026-02-03T14:00:00.000Z"
  },
  "message": "Success"
}
```

#### 10. 获取公益文章列表（管理员）

- **接口**: `GET \/charity\/admin/:id/articles`
- **权限**: ✅ 需要登录 🎭 SUPER_ADMIN、HOSPITAL_ADMIN、STAFF
- **说明**: 返回该公益下全部已发布文章，不按当前登录管理员过滤 `targetUserIds`
- **补充说明**: `participantType=donation` 的公益固定返回空数组

**响应示例**:

```json
{
  "code": 0,
  "data": [
    {
      "id": 1,
      "charityId": 1,
      "title": "公益总结",
      "content": "恭喜大家完成公益！",
      "publisherId": 1,
      "targetUserIds": [1, 2, 3],
      "sendNotification": true,
      "isPublished": true,
      "createdAt": "2026-02-03T14:00:00.000Z"
    }
  ],
  "message": "Success"
}
```

---

### 前端调用示例

```typescript
import {
  getCharityListAdminApi,
  createCharityApi,
  updateCharityApi,
  deleteCharityApi,
  getCharityStatsApi,
  getParticipantsApi,
  publishCharityArticleApi,
  updateCharityArticleApi,
  getPublishedArticleApi,
  getCharityArticlesApi
} from '@/api-new/charity'

// 管理端 - 获取公益列表
const charities = await getCharityListAdminApi({
  status: 'ACTIVE',
  deleteStatus: 'active',
  keyword: '健康',
  page: 1,
  pageSize: 10
})

// 管理员 - 创建公益
await createCharityApi({
  title: '7天健康打卡',
  description: '连续打卡7天',
  details: '<p>活动说明</p>',
  targetCheckIns: 7,
  participantType: 'checkin'
})

// 管理员 - 更新公益
await updateCharityApi(1, {
  title: '7天健康打卡（春季版）'
})

// 管理员 - 获取统计数据
const stats = await getCharityStatsApi(1)
console.log('完成率:', stats.data.completionRate)

// 管理员 - 获取文章列表（不过滤当前 admin）
const articles = await getCharityArticlesApi(1)
console.log('文章数:', articles.data.length)

// 管理员 - 删除公益（软删除，有参与者也可删除）
await deleteCharityApi(2)
```

---

### 业务规则

1. **签到限制**: 每个用户每天只能签到一次（通过数据库唯一索引保证）
2. **状态自动更新**:
   - 公益状态会在调用列表、详情接口时自动检查并更新
   - 超过结束时间的公益自动变为 EXPIRED
   - 打卡类型在 `completedCheckIns >= targetCheckIns` 时自动变为 EXPIRED
3. **打卡类型规则**:
   - 每次用户打卡后，公益的 completedCheckIns 字段会自动 +1
   - 前端使用 completedCheckIns 字段来计算和显示公益整体进度
4. **捐款类型规则**:
   - 不需要配置 `targetCheckIns`
   - 列表、详情接口会额外返回 `donatedAmount`
   - 管理端不应展示“发布文章 / 文章列表”入口
5. **公益删除**: 当前实现仅校验“没有参与者”才能删除，不额外限制草稿状态
6. **文章发布**:
   - **公益必须已结束**（状态为 EXPIRED）才能发布文章
   - **每个公益只能发布一篇文章**
   - **仅打卡类型公益支持文章功能**
   - 发布后可以编辑文章内容
   - 可选择是否发送通知
   - 可指定目标用户，为空则发送给所有参与者

---

## Activities 模块

活动管理模块，支持线下报名、线上投票与参与记录查询。

### 核心数据结构

```typescript
enum ActivityStatus {
  UPCOMING = 'UPCOMING',
  ONGOING = 'ONGOING',
  EXPIRED = 'EXPIRED'
}

interface Activity {
  id: number
  title: string
  startTime: number
  endTime: number
  location?: string
  summary: string
  description: string
  coverImage?: string
  showOnHome?: boolean
  hospitalId: number
  activityType: 'OFFLINE' | 'ONLINE'
  voteOptions?: ActivityVoteOption[]
  registrationCount?: number
  commentCount?: number
  status?: ActivityStatus
  hospitalName?: string
  hospitalData?: {
    id: number
    name: string
    logo?: string
    city?: string
    address?: string
    phone?: string
  }
  isRegistered?: boolean
  canRegister?: boolean
  createdAt: number
  updatedAt: number
}

interface ActivityVoteOption {
  id: number
  activityId: number
  image: string // 图片和视频至少返回一个
  video?: string // 图片和视频至少返回一个
  videoCover?: string
  title: string
  description?: string
  voteCount: number
  sortOrder: number
  ownerUserId?: number | null // 所属账号 ID，管理端创建的历史选手可为空
}

interface ActivityComment {
  id: number
  activityId: number
  userId: number
  content: string
  parentId?: number | null
  likeCount: number
  createdAt: string
  user?: {
    id: number
    nickname: string
    avatar?: string
  }
  replies?: ActivityComment[]
}
```

### 接口总览

| HTTP 方法 | 路径 | 描述 | 权限 |
| --- | --- | --- | --- |
| GET | /activities/app | 获取活动列表（用户端） | 🌐（可选 JWT） |
| GET | /activities/app/:id | 获取活动详情（用户端） | 🌐（可选 JWT） |
| POST | /activities/app/:id/register | 线下活动报名 | ✅ USER |
| GET | /activities/app/:id/participants | 获取活动参与者列表（用户端） | 🌐（可选 JWT） |
| GET | /activities/app/:id/comments | 获取活动评论列表（用户端，仅投票活动） | 🌐（可选 JWT） |
| POST | /activities/app/:id/comments | 发表评论/回复活动评论（仅投票活动） | ✅ USER |
| POST | /activities/app/:id/vote | 线上活动投票 | ✅ USER |
| POST | /activities/app/:id/vote-options | 线上投票活动报名创建选手 | ✅ USER |
| PUT | /activities/app/:id/vote-options/:optionId | 编辑本人创建的线上投票选手 | ✅ USER |
| DELETE | /activities/app/:id/vote-options/:optionId | 删除本人创建的线上投票选手 | ✅ USER |
| GET | /activities/app/:id/vote-options/:optionId/comments | 获取选手评论列表（用户端，仅投票活动） | 🌐（可选 JWT） |
| POST | /activities/app/:id/vote-options/:optionId/comments | 发表评论/回复选手评论（仅投票活动） | ✅ USER |
| GET | /activities/admin/list | 获取活动列表（管理员） | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF |
| POST | /activities/admin | 创建活动 | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF |
| PUT | /activities/admin/:id | 更新活动 | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF |
| DELETE | /activities/admin/:id | 删除活动 | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF |
| GET | /activities/admin/:id/registrations | 获取活动参与/投票用户列表 | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF |
| GET | /activities/admin/:id/comments | 获取活动评论列表（管理员） | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF |
| DELETE | /activities/admin/comments/:commentId | 删除活动评论及其下级回复 | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF |

> NOTE: 后端当前没有 `GET /activities/admin/:id` 独立详情接口，管理端如需单条详情请复用 `GET /activities/app/:id` 或列表行数据。

### 标准成功响应

活动接口遵循统一成功包裹格式：

```json
{
  "code": 0,
  "data": [],
  "message": "Success",
  "pagination": {
    "total": 20,
    "page": 1,
    "totalPages": 2
  }
}
```

### 分页字段说明

- 分页接口会在最外层返回 `pagination`
- rnapp 应读取最外层 `data` 作为业务数组，读取最外层 `pagination` 作为分页信息
- 请优先使用 `pagination.total`、`pagination.page`、`pagination.totalPages`
- 页大小请以前端请求参数 `pageSize` 为准；若运行时额外出现 `pagination.limit`，可视为 `pageSize` 的同义字段

### 获取活动列表（用户端）

**端点:** `GET /activities/app`

**权限:** 🌐 匿名可访问，可选携带 JWT

**说明:** 携带用户 JWT 时，响应中每条活动会额外返回 `isRegistered` 与 `canRegister`。用户端仅返回未删除活动，已软删除数据不会展示。

**查询参数:**

| 参数     | 类型                                 | 必填 | 说明               |
| -------- | ------------------------------------ | ---- | ------------------ |
| status   | `UPCOMING` \| `ONGOING` \| `EXPIRED` | 否   | 按实时状态筛选     |
| keyword  | string                               | 否   | 按活动名称模糊搜索 |
| showOnHome | boolean                            | 否   | 是否仅查询展示到首页的活动 |
| page     | number                               | 否   | 页码，默认 1       |
| pageSize | number                               | 否   | 每页数量，默认 10  |

**响应示例:**

```json
{
  "code": 0,
  "data": [
    {
      "id": 1,
      "title": "宠物健康讲座",
      "startTime": 1770652800,
      "endTime": 1771084799,
      "location": "北京市朝阳区 XX 路 18 号",
      "summary": "专业兽医现场答疑",
      "description": "<p>详细的活动安排</p>",
      "coverImage": "/uploads/activity-cover.jpg",
      "sharePosterImage": "/uploads/activity-share-poster.jpg",
      "sharePosterTitle": "扫码参与",
      "sharePosterDescription": "长按识别二维码查看活动详情",
      "showOnHome": true,
      "hospitalId": 3,
      "activityType": "OFFLINE",
      "registrationCount": 26,
      "status": "ONGOING",
      "hospitalName": "朝阳宠物医院",
      "isRegistered": true,
      "canRegister": false,
      "createdAt": 1769900000000,
      "updatedAt": 1770100000000
    }
  ],
  "message": "Success",
  "pagination": {
    "total": 6,
    "page": 1,
    "totalPages": 1
  }
}
```

### 获取活动列表（管理员）

**端点:** `GET /activities/admin/list`

**查询参数:**

| 参数         | 类型   | 必填 | 说明                                                     |
| ------------ | ------ | ---- | -------------------------------------------------------- |
| hospitalId   | number | 否   | 按医院筛选                                               |
| startDate    | string | 否   | 按开始日期筛选，格式 `YYYY-MM-DD`                        |
| status       | string | 否   | 活动状态：UPCOMING / ONGOING / EXPIRED                  |
| deleteStatus | string | 否   | 删除状态：active=未删除（默认），deleted=已删除，all=全部 |
| showOnHome   | boolean | 否  | 是否仅查询展示到首页的活动                               |
| keyword      | string | 否   | 按活动名称模糊搜索                                       |
| page         | number | 否   | 页码，默认 1                                             |
| pageSize     | number | 否   | 每页数量，默认 10                                        |

**响应示例:**

```json
{
  "code": 0,
  "data": [
    {
      "id": 1,
      "title": "宠物健康讲座",
      "startTime": 1770652800,
      "endTime": 1771084799,
      "location": "北京市朝阳区 XX 路 18 号",
      "summary": "专业兽医现场答疑",
      "description": "<p>讲解疫苗、驱虫和老年宠护理。</p>",
      "coverImage": "/uploads/activity-cover.jpg",
      "sharePosterImage": "/uploads/activity-share-poster.jpg",
      "sharePosterTitle": "扫码参与",
      "sharePosterDescription": "长按识别二维码查看活动详情",
      "hospitalId": 3,
      "activityType": "ONLINE",
      "voteOptions": [
        {
          "id": 1,
          "activityId": 1,
          "image": "/uploads/vote-option-1.jpg",
          "video": "/uploads/vote-option-1.mp4",
          "videoCover": "/uploads/thumbnails/vote-option-1.jpg",
          "title": "小白",
          "description": "三岁金毛，温顺亲人",
          "voteCount": 12,
          "sortOrder": 0,
          "ownerUserId": 8
        }
      ],
      "registrationCount": 26,
      "commentCount": 8,
      "status": "ONGOING",
      "hospitalName": "朝阳宠物医院",
      "hospitalData": {
        "id": 3,
        "name": "朝阳宠物医院",
        "logo": "/uploads/hospital-3.png",
        "city": "北京市",
        "address": "北京市朝阳区 XX 路 18 号",
        "phone": "010-88886666"
      },
      "deletedAt": null,
      "createdAt": 1769900000000,
      "updatedAt": 1770100000000
    }
  ],
  "message": "Success",
  "pagination": {
    "total": 6,
    "page": 1,
    "pageSize": 10,
    "totalPages": 1
  }
}
```

### 线下活动报名

**端点:** `POST /activities/app/:id/register`

**权限:** ✅ USER

**请求体:**

```json
{
  "phone": "13800138000"
}
```

**响应示例:**

```json
{
  "code": 0,
  "data": {
    "success": true,
    "message": "报名成功",
    "data": {
      "registrationId": 12,
      "registeredAt": 1770201000000
    }
  },
  "message": "报名成功"
}
```

**字段说明:**

- 最外层 `data` 不是报名记录本身，而是完整保留的业务载荷
- 真正的报名结果位于 `data.data.registrationId` 与 `data.data.registeredAt`
- 最外层 `message` 与内层 `data.message` 当前都会返回“报名成功”

> NOTE: `POST /activities/app/:id/register` 属于操作态接口，后端当前会保留内层 `success/message/data` 结构；rnapp 联调时不要将最外层 `data` 误当成最终报名对象。

**常见错误响应:**

- 未登录、非法 JWT、过期 JWT：由 `HttpExceptionFilter` 输出 HTTP 200 + `statusCode=401`（其中无 token、坏签名 token、过期 token 已通过真实轻量集成回归覆盖）
- 已重复报名：由 `BusinessExceptionFilter` 输出 HTTP 200 + `statusCode=400` 业务错误

```json
{
  "success": false,
  "code": 401,
  "statusCode": 401,
  "timestamp": "2026-03-11T08:00:00.000Z",
  "path": "/activities/app/1/register",
  "method": "POST",
  "message": "Unauthorized",
  "error": "UnauthorizedException"
}
```

```json
{
  "success": false,
  "statusCode": 400,
  "message": "您已经报名过该活动",
  "code": "3000",
  "error": "BUSINESS_ERROR",
  "timestamp": "2026-03-11T08:00:00.000Z",
  "path": "/activities/app/1/register",
  "method": "POST"
}
```

### 线上活动投票

**端点:** `POST /activities/app/:id/vote`

**权限:** ✅ USER

**说明:**

- 线上活动不需要填写手机号，登录后即可投票
- 必须传入选手 ID，服务端会校验选手属于当前活动，并累加该选手票数
- 每个用户对同一活动每天只能投票一次；响应中的 `isRegistered` 对线上活动表示“当前用户今天是否已投票”

**请求体:**

```json
{
  "optionId": 1
}
```

**响应示例:**

```json
{
  "code": 0,
  "data": {
    "success": true,
    "message": "投票成功",
    "data": {
      "voteId": 12,
      "votedAt": 1770201000000,
      "optionId": 1
    }
  },
  "message": "投票成功"
}
```

### 线上投票活动报名创建选手

**端点:** `POST /activities/app/:id/vote-options`

**权限:** ✅ USER

**说明:**

- 仅线上投票活动可用，线下活动请使用 `POST /activities/app/:id/register`
- 请求成功后会在 `activity_vote_options.ownerUserId` 写入当前登录账号 ID
- 图片和视频至少传一个；标题必填
- 创建选手不会等同于投票，不会占用“每天一票”的投票次数

**请求体:**

```json
{
  "image": "/uploads/vote-option-1.jpg",
  "video": "/uploads/vote-option-1.mp4",
  "videoCover": "/uploads/thumbnails/vote-option-1.jpg",
  "title": "小白",
  "description": "三岁金毛，温顺亲人"
}
```

**响应示例:**

```json
{
  "code": 0,
  "data": {
    "success": true,
    "message": "报名成功",
    "data": {
      "id": 21,
      "activityId": 1,
      "image": "/uploads/vote-option-1.jpg",
      "video": "/uploads/vote-option-1.mp4",
      "videoCover": "/uploads/thumbnails/vote-option-1.jpg",
      "title": "小白",
      "description": "三岁金毛，温顺亲人",
      "voteCount": 0,
      "sortOrder": 3,
      "ownerUserId": 8,
      "createdAt": 1770201000000,
      "updatedAt": 1770201000000
    }
  },
  "message": "报名成功"
}
```

### 编辑本人创建的线上投票选手

**端点:** `PUT /activities/app/:id/vote-options/:optionId`

**权限:** ✅ USER

**说明:**

- 仅允许编辑当前账号创建的选手，即 `ownerUserId === 当前用户 ID`
- 服务端会校验选手属于当前活动
- 图片和视频至少传一个；标题必填
- 编辑不会重置票数和排序

**请求体:**

```json
{
  "image": "/uploads/vote-option-1-new.jpg",
  "video": "",
  "videoCover": "",
  "title": "小白更新",
  "description": "更新后的参赛说明"
}
```

**响应示例:**

```json
{
  "code": 0,
  "data": {
    "success": true,
    "message": "保存成功",
    "data": {
      "id": 21,
      "activityId": 1,
      "image": "/uploads/vote-option-1-new.jpg",
      "video": "",
      "videoCover": "",
      "title": "小白更新",
      "description": "更新后的参赛说明",
      "voteCount": 18,
      "sortOrder": 3,
      "ownerUserId": 8,
      "createdAt": 1770201000000,
      "updatedAt": 1770203000000
    }
  },
  "message": "保存成功"
}
```

### 删除本人创建的线上投票选手

**端点:** `DELETE /activities/app/:id/vote-options/:optionId`

**权限:** ✅ USER

**说明:**

- 仅允许删除当前账号创建的选手，即 `ownerUserId === 当前用户 ID`
- 仅活动结束前可删除；服务端会校验选手属于当前线上投票活动
- 删除会软删除选手及其评论，并删除该选手的投票记录
- 删除后会重算活动参与人数；曾投给该选手的用户可以重新投票

**响应示例:**

```json
{
  "code": 0,
  "data": {
    "success": true,
    "message": "删除成功"
  },
  "message": "删除成功"
}
```

### 获取活动参与者列表（用户端）

**端点:** `GET /activities/app/:id/participants`

**说明:** 线上活动用于展示投票人列表，线下活动也会返回报名人列表。

**查询参数:**

| 参数     | 类型   | 必填 | 说明              |
| -------- | ------ | ---- | ----------------- |
| page     | number | 否   | 页码，默认 1      |
| pageSize | number | 否   | 每页数量，默认 10 |

**响应示例:**

```json
{
  "code": 0,
  "data": [
    {
      "userId": 8,
      "userName": "李四",
      "userAvatar": "/uploads/avatar-8.jpg",
      "registeredAt": 1770201000000
    }
  ],
  "message": "Success",
  "pagination": {
    "total": 26,
    "page": 1,
    "pageSize": 10,
    "totalPages": 3
  }
}
```

### 获取活动评论列表（用户端）

**端点:** `GET /activities/app/:id/comments`

**权限:** 🌐 匿名可访问，可选携带 JWT

**说明:** 仅线上投票活动可用。评论数据独立存储在 `activity_comments` 表，不复用社区帖子评论表。该接口只返回活动级评论，即 `voteOptionId` 为空的评论。

**查询参数:**

| 参数     | 类型   | 必填 | 说明              |
| -------- | ------ | ---- | ----------------- |
| page     | number | 否   | 页码，默认 1      |
| pageSize | number | 否   | 每页数量，默认 20 |

**响应示例:**

```json
{
  "code": 0,
  "data": [
    {
      "id": 31,
      "activityId": 1,
      "voteOptionId": null,
      "userId": 8,
      "content": "小白太可爱了，支持一下",
      "parentId": null,
      "likeCount": 0,
      "createdAt": "2026-05-30T10:00:00.000Z",
      "user": {
        "id": 8,
        "nickname": "李四",
        "avatar": "/uploads/avatar-8.jpg"
      },
      "replies": [
        {
          "id": 32,
          "activityId": 1,
          "voteOptionId": null,
          "userId": 9,
          "content": "一起加油",
          "parentId": 31,
          "likeCount": 0,
          "createdAt": "2026-05-30T10:05:00.000Z",
          "user": {
            "id": 9,
            "nickname": "王五",
            "avatar": "/uploads/avatar-9.jpg"
          }
        }
      ]
    }
  ],
  "message": "Success",
  "pagination": {
    "total": 1,
    "page": 1,
    "pageSize": 20,
    "totalPages": 1
  }
}
```

### 发表评论/回复活动评论（用户端）

**端点:** `POST /activities/app/:id/comments`

**权限:** ✅ USER

**说明:** 仅线上投票活动可用。传 `parentId` 时表示回复指定活动评论，服务端会校验父评论属于同一个活动，且同样属于活动级评论。

**请求体:**

```json
{
  "content": "我也来支持",
  "parentId": 31
}
```

**响应示例:**

```json
{
  "code": 0,
  "data": {
    "id": 33,
    "activityId": 1,
    "voteOptionId": null,
    "userId": 8,
    "content": "我也来支持",
    "parentId": 31,
    "likeCount": 0,
    "createdAt": "2026-05-30T10:10:00.000Z",
    "user": {
      "id": 8,
      "nickname": "李四",
      "avatar": "/uploads/avatar-8.jpg"
    }
  },
  "message": "评论成功"
}
```

### 获取选手评论列表（用户端）

**端点:** `GET /activities/app/:id/vote-options/:optionId/comments`

**权限:** 🌐 匿名可访问，可选携带 JWT

**说明:** 仅线上投票活动可用。服务端会校验 `optionId` 属于当前活动。该接口只返回指定选手的评论，与活动级评论、其他选手评论互相隔离。

**查询参数:**

| 参数     | 类型   | 必填 | 说明              |
| -------- | ------ | ---- | ----------------- |
| page     | number | 否   | 页码，默认 1      |
| pageSize | number | 否   | 每页数量，默认 20 |

**响应示例:**

```json
{
  "code": 0,
  "data": [
    {
      "id": 41,
      "activityId": 1,
      "voteOptionId": 21,
      "userId": 8,
      "content": "小白太可爱了，支持一下",
      "parentId": null,
      "likeCount": 0,
      "createdAt": "2026-05-30T10:00:00.000Z",
      "user": {
        "id": 8,
        "nickname": "李四",
        "avatar": "/uploads/avatar-8.jpg"
      },
      "replies": []
    }
  ],
  "message": "Success",
  "pagination": {
    "total": 1,
    "page": 1,
    "pageSize": 20,
    "totalPages": 1
  }
}
```

### 发表评论/回复选手评论（用户端）

**端点:** `POST /activities/app/:id/vote-options/:optionId/comments`

**权限:** ✅ USER

**说明:** 仅线上投票活动可用。服务端会校验 `optionId` 属于当前活动。传 `parentId` 时表示回复指定选手评论，父评论必须属于同一活动和同一选手。

**请求体:**

```json
{
  "content": "我也来支持",
  "parentId": 41
}
```

**响应示例:**

```json
{
  "code": 0,
  "data": {
    "id": 42,
    "activityId": 1,
    "voteOptionId": 21,
    "userId": 8,
    "content": "我也来支持",
    "parentId": 41,
    "likeCount": 0,
    "createdAt": "2026-05-30T10:10:00.000Z",
    "user": {
      "id": 8,
      "nickname": "李四",
      "avatar": "/uploads/avatar-8.jpg"
    }
  },
  "message": "评论成功"
}
```

### 创建 / 更新活动

**端点:**

- `POST /activities/admin`
- `PUT /activities/admin/:id`

**请求体:**

```json
{
  "title": "宠物健康讲座",
  "startTime": "2026-02-10",
  "endTime": "2026-02-15",
  "activityType": "OFFLINE",
  "location": "北京市朝阳区 XX 路 18 号",
  "summary": "专业兽医现场答疑",
  "description": "<p>详细的活动安排</p>",
  "coverImage": "/uploads/activity-cover.jpg",
  "sharePosterImage": "/uploads/activity-share-poster.jpg",
  "sharePosterTitle": "扫码参与",
  "sharePosterDescription": "长按识别二维码查看活动详情",
  "showOnHome": false,
  "hospitalId": 3,
  "voteOptions": []
}
```

**字段说明:**

| 字段         | 类型   | 必填 | 说明                           |
| ------------ | ------ | ---- | ------------------------------ |
| title        | string | 是   | 活动名称                       |
| startTime    | string | 是   | 开始日期，格式 `YYYY-MM-DD`    |
| endTime      | string | 是   | 结束日期，格式 `YYYY-MM-DD`    |
| activityType | string | 是   | 活动类型：`OFFLINE` / `ONLINE` |
| location     | string | 否   | 活动地点，线下活动必填         |
| summary      | string | 是   | 活动简介                       |
| description  | string | 是   | 活动详情（富文本 HTML）        |
| coverImage   | string | 否   | 活动封面图 URL                 |
| sharePosterImage | string | 否 | 分享海报图 URL，建议 9:16      |
| sharePosterTitle | string | 否 | 海报提示标题，最多 10 个字     |
| sharePosterDescription | string | 否 | 海报提示信息，最多 30 个字     |
| showOnHome   | boolean | 否  | 是否展示到 App 首页，默认 `false` |
| hospitalId   | number | 是   | 关联医院 ID                    |
| voteOptions  | array  | 否   | 线上投票选手列表，可省略或传空数组；已添加的选手 `title` 必填，`image`/`video` 至少传一个 |

线上投票创建/更新请求体示例：

```json
{
  "title": "春季萌宠人气评选",
  "startTime": "2026-02-10",
  "endTime": "2026-02-15",
  "activityType": "ONLINE",
  "summary": "为喜欢的萌宠投票",
  "description": "<p>每人每天限投一票</p>",
  "coverImage": "/uploads/activity-cover.jpg",
  "sharePosterImage": "/uploads/activity-share-poster.jpg",
  "sharePosterTitle": "扫码投票",
  "sharePosterDescription": "为喜欢的萌宠助力",
  "hospitalId": 3,
  "voteOptions": [
    {
      "image": "/uploads/vote-option-1.jpg",
      "video": "/uploads/vote-option-1.mp4",
      "videoCover": "/uploads/thumbnails/vote-option-1.jpg",
      "title": "小白",
      "description": "三岁金毛，温顺亲人",
      "voteCount": 0,
      "sortOrder": 0,
      "ownerUserId": null
    }
  ]
}
```

线上活动发布时不要求预先添加选手，`voteOptions` 可省略或传空数组。若传入选手，仍需填写标题，并至少上传图片或视频。

### 删除活动

**端点:** `DELETE /activities/admin/:id`

**说明:** 软删除活动；报名/投票记录和线上投票选手数据会保留。可通过活动列表接口 `deleteStatus=deleted` 或 `deleteStatus=all` 查询已删除数据。

### 获取活动参与/投票用户列表

**端点:** `GET /activities/admin/:id/registrations`

**说明:** 该接口同时用于线下活动的报名名单和线上活动的投票名单。

**查询参数:**

| 参数     | 类型   | 必填 | 说明              |
| -------- | ------ | ---- | ----------------- |
| page     | number | 否   | 页码，默认 1      |
| pageSize | number | 否   | 每页数量，默认 10 |
| voteOptionId | number | 否 | 线上投票选手 ID；传入后只返回该选手的投票用户 |

**响应示例:**

```json
{
  "code": 0,
  "data": [
    {
      "id": 11,
      "activityId": 1,
      "userId": 8,
      "phone": "13800138008",
      "voteOptionId": 1,
      "registeredAt": 1770201000000,
      "userName": "李四",
      "userAvatar": "/uploads/avatar-8.jpg"
    }
  ],
  "message": "Success",
  "pagination": {
    "total": 26,
    "page": 1,
    "pageSize": 10,
    "totalPages": 3
  }
}
```

### 获取活动评论列表（管理员）

**端点:** `GET /activities/admin/:id/comments`

**说明:** 仅线上投票活动可用。用于管理端活动列表“查看评论”抽屉，返回顶级评论及当前页评论的直接回复。

**查询参数:**

| 参数     | 类型   | 必填 | 说明              |
| -------- | ------ | ---- | ----------------- |
| page     | number | 否   | 页码，默认 1      |
| pageSize | number | 否   | 每页数量，默认 10 |

**响应示例:**

```json
{
  "code": 0,
  "data": [
    {
      "id": 31,
      "activityId": 1,
      "userId": 8,
      "content": "小白太可爱了，支持一下",
      "parentId": null,
      "likeCount": 0,
      "createdAt": "2026-05-30T10:00:00.000Z",
      "user": {
        "id": 8,
        "nickname": "李四",
        "avatar": "/uploads/avatar-8.jpg"
      },
      "replies": [
        {
          "id": 32,
          "activityId": 1,
          "userId": 9,
          "content": "一起加油",
          "parentId": 31,
          "likeCount": 0,
          "createdAt": "2026-05-30T10:05:00.000Z",
          "user": {
            "id": 9,
            "nickname": "王五",
            "avatar": "/uploads/avatar-9.jpg"
          }
        }
      ]
    }
  ],
  "message": "Success",
  "pagination": {
    "total": 8,
    "page": 1,
    "pageSize": 10,
    "totalPages": 1
  }
}
```

### 删除活动评论（管理员）

**端点:** `DELETE /activities/admin/comments/:commentId`

**说明:** 软删除该评论及其所有下级回复。删除后 App 端评论列表不再返回这些评论。

**响应示例:**

```json
{
  "code": 0,
  "data": {
    "message": "删除成功",
    "data": {
      "deletedCount": 3
    }
  },
  "message": "删除成功"
}
```

### 获取活动详情（用户端）

**端点:** `GET /activities/app/:id`

**权限:** 🌐 匿名可访问，可选携带 JWT

**说明:** 携带用户 JWT 时，响应会追加 `isRegistered` 与 `canRegister` 字段；未登录时这两个字段会回退为基于匿名态计算的默认值。

**响应示例:**

```json
{
  "code": 0,
  "data": {
    "id": 1,
    "title": "宠物健康讲座",
    "startTime": 1770652800,
    "endTime": 1771084799,
    "location": "北京市朝阳区 XX 路 18 号",
    "summary": "专业兽医现场答疑",
    "description": "<p>详细的活动安排</p>",
    "coverImage": "/uploads/activity-cover.jpg",
    "sharePosterImage": "/uploads/activity-share-poster.jpg",
    "sharePosterTitle": "扫码参与",
    "sharePosterDescription": "长按识别二维码查看活动详情",
    "showOnHome": true,
    "hospitalId": 3,
    "activityType": "ONLINE",
    "voteOptions": [
      {
        "id": 1,
        "activityId": 1,
        "image": "/uploads/vote-option-1.jpg",
        "video": "/uploads/vote-option-1.mp4",
        "videoCover": "/uploads/thumbnails/vote-option-1.jpg",
        "title": "小白",
        "description": "三岁金毛，温顺亲人",
        "voteCount": 12,
        "sortOrder": 0,
        "ownerUserId": 8
      }
    ],
    "registrationCount": 26,
    "status": "ONGOING",
    "hospitalName": "朝阳宠物医院",
    "isRegistered": true,
    "canRegister": false
  },
  "message": "Success"
}
```

### 业务规则

1. 活动状态由当前时间实时计算，不单独持久化存储。
2. 创建和更新活动时，服务端会将 `startTime` 归一化到当天 `00:00:00`，`endTime` 归一化到当天 `23:59:59`。
3. 线下活动使用报名接口；线上活动可先发布再使用 `vote-options` 创建选手，并使用 `vote` 参与投票。线上投票按活动 + 用户 + 当天日期防重复投票。
4. 用户端创建线上投票选手时会记录 `ownerUserId`；详情页可用 `ownerUserId === 当前账号 ID` 判断是否展示编辑和删除入口。删除选手时会同步清理其评论与投票记录，并重算活动参与人数。
5. 活动评论仅对线上投票活动开放，使用独立 `activity_comments` 表，和社区帖子评论表互不复用。
6. 管理端列表会补充 `registrationCount`、`commentCount`、`hospitalName` 与 `hospitalData`，便于管理端直接回显。
7. 管理端删除活动评论会软删除该评论及其所有下级回复；App 端评论列表不会返回已软删除评论。

---

**文档最后更新时间:** 2026-08-02

---

---

## Lost Found 模块

宠物走失 / 领养管理

| HTTP 方法 | 路径                     | 描述                  | 权限         |
| --------- | ------------------------ | --------------------- | ------------ |
| GET       | /lost-found              | 获取走失/领养信息列表 | 🌐           |
| GET       | /lost-found/:id          | 获取走失/领养信息详情 | 🌐           |
| POST      | /lost-found              | 创建走失/领养信息     | ✅           |
| PUT       | /lost-found/:id          | 更新走失/领养信息     | ✅           |
| PATCH     | /lost-found/:id/pin      | 设置/取消置顶         | ✅ 🎭 管理员 |
| PATCH     | /lost-found/:id/found    | 标记已找回（仅走失）  | ✅           |
| DELETE    | /lost-found/:id          | 删除走失/领养信息     | ✅           |
| GET       | /lost-found/:id/comments | 获取走失/领养评论列表 | 🌐           |
| POST      | /lost-found/:id/comments | 发表评论/回复走失评论 | ✅           |

---

### 1. 获取走失 / 领养信息列表

- **接口**: `GET /lost-found`
- **权限**: 🌐 公开接口
- **说明**: 支持分页、按记录类型筛选和关键词搜索，置顶记录优先显示

**查询参数**:

| 参数        | 类型    | 必填 | 说明                                   |
| ----------- | ------- | ---- | -------------------------------------- |
| page        | number  | 否   | 页码，默认 1                           |
| pageSize    | number  | 否   | 每页数量，默认 10                      |
| recordType  | string  | 否   | 记录类型：`LOST`=走失，`ADOPTION`=领养 |
| isFound     | boolean | 否   | 筛选是否已找回，仅 `LOST` 记录生效     |
| isPinned    | boolean | 否   | 筛选是否置顶                           |
| petId       | number  | 否   | 筛选宠物 ID                            |
| publisherId | number  | 否   | 筛选发布者 ID                          |
| keyword     | string  | 否   | 搜索关键词（宠物快照、描述、联系人姓名） |

**响应示例**:

```json
{
  "code": 0,
  "data": [
    {
      "id": 1,
      "petId": 10,
      "petName": "旺财",
      "petCategory": "狗",
      "petBreed": "金毛",
      "pet": {
        "id": 10,
        "name": "旺财",
        "avatar": "/uploads/pets/avatar.jpg",
        "category": {
          "id": 1,
          "name": "狗"
        },
        "subCategory": {
          "id": 10,
          "name": "金毛"
        }
      },
      "publisherId": 1,
      "publisher": {
        "id": 1,
        "username": "张三",
        "avatar": "/uploads/users/avatar.jpg"
      },
      "publisherType": "USER",
      "recordType": "LOST",
      "contactName": "李四",
      "contactPhone": "13900139000",
      "description": "金毛犬旺财于2月1日下午在公园走失，身高约60cm，身穿红色背心，性格温顺",
      "images": ["/uploads/lost-found/1.jpg", "/uploads/lost-found/2.jpg"],
      "video": "/uploads/lost-found/demo.mp4",
      "videoCover": "/uploads/lost-found/demo_cover.jpg",
      "isPinned": true,
      "isFound": false,
      "foundAt": null,
      "createdAt": "2026-02-01T14:00:00.000Z",
      "updatedAt": "2026-02-01T14:00:00.000Z"
    }
  ],
  "pagination": {
    "total": 100,
    "page": 1,
    "limit": 10,
    "totalPages": 10
  },
  "message": "Success"
}
```

---

### 2. 获取走失 / 领养信息详情

- **接口**: `GET /lost-found/:id`
- **权限**: 🌐 公开接口
- **说明**: 根据 ID 获取走失 / 领养信息详情

**路径参数**:

| 参数 | 类型   | 必填 | 说明        |
| ---- | ------ | ---- | ----------- |
| id   | number | 是   | 走失信息 ID |

**响应示例**:

```json
{
  "code": 0,
  "data": {
    "id": 1,
    "petId": null,
    "petName": "小黑",
    "petCategory": "狗",
    "petBreed": "中华田园犬",
    "pet": null,
    "publisherId": 1,
    "publisher": {
      "id": 1,
      "username": "张三",
      "avatar": "/uploads/users/avatar.jpg"
    },
    "publisherType": "USER",
    "recordType": "LOST",
    "contactName": "李四",
    "contactPhone": "13900139000",
    "description": "中华田园犬小黑于2月1日下午在公园走失，佩戴蓝色项圈，性格温顺",
    "images": ["/uploads/lost-found/1.jpg", "/uploads/lost-found/2.jpg"],
    "video": "/uploads/lost-found/demo.mp4",
    "videoCover": "/uploads/lost-found/demo_cover.jpg",
    "isPinned": true,
    "isFound": false,
    "foundAt": null,
    "createdAt": "2026-02-01T14:00:00.000Z",
    "updatedAt": "2026-02-01T14:00:00.000Z"
  },
  "message": "Success"
}
```

---

### 3. 创建走失 / 领养信息

- **接口**: `POST /lost-found`
- **权限**: ✅ 需要登录
- **说明**:
  - 关联宠物档案时，普通用户只能选择自己的宠物，服务端会生成名称、类别和品种快照
  - 发布非系统宠物时不传 `petId`，改为完整传入 `petName`、`petCategory`、`petBreed`
  - 管理员可以发布任何宠物的走失或领养信息

**请求体**:

| 字段         | 类型     | 必填 | 说明                                                |
| ------------ | -------- | ---- | --------------------------------------------------- |
| petId        | number   | 条件 | 宠物 ID；与手动宠物三个字段二选一                   |
| petName      | string   | 条件 | 手动宠物名称（最多 50 字）                          |
| petCategory  | string   | 条件 | 手动宠物类别（最多 50 字）                          |
| petBreed     | string   | 条件 | 手动宠物品种（最多 100 字）                         |
| recordType   | string   | 否   | 记录类型：`LOST`=走失，`ADOPTION`=领养，默认 `LOST` |
| contactName  | string   | 是   | 联系人姓名（2-20 字）                               |
| contactPhone | string   | 是   | 联系电话（11 位手机号）                             |
| description  | string   | 是   | 描述（10-500 字）                                   |
| images       | string[] | 否   | 图片 URL 列表（最多 9 张）                          |
| video        | string   | 否   | 视频 URL                                            |
| videoCover   | string   | 否   | 视频封面图 URL                                      |
| isFound      | boolean  | 否   | 是否已找回，仅 `LOST` 记录生效                      |

**请求示例**:

```json
{
  "petId": 10,
  "recordType": "ADOPTION",
  "contactName": "李四",
  "contactPhone": "13900139000",
  "description": "金毛犬旺财性格温顺，已绝育，疫苗齐全，希望在上海地区寻找稳定领养家庭",
  "images": ["/uploads/lost-found/1.jpg", "/uploads/lost-found/2.jpg"],
  "video": "/uploads/lost-found/demo.mp4",
  "videoCover": "/uploads/lost-found/demo_cover.jpg"
}
```

手动填写非系统宠物：

```json
{
  "petId": null,
  "petName": "小黑",
  "petCategory": "狗",
  "petBreed": "中华田园犬",
  "recordType": "ADOPTION",
  "contactName": "李四",
  "contactPhone": "13900139000",
  "description": "性格亲人，疫苗齐全，希望寻找稳定领养家庭"
}
```

**响应示例**:

```json
{
  "code": 0,
  "data": {
    "id": 1,
    "petId": null,
    "petName": "小黑",
    "petCategory": "狗",
    "petBreed": "中华田园犬",
    "pet": null,
    "publisherId": 1,
    "publisherType": "USER",
    "recordType": "ADOPTION",
    "contactName": "李四",
    "contactPhone": "13900139000",
    "description": "中华田园犬小黑性格温顺，疫苗齐全，希望寻找稳定领养家庭",
    "images": ["/uploads/lost-found/1.jpg", "/uploads/lost-found/2.jpg"],
    "video": "/uploads/lost-found/demo.mp4",
    "videoCover": "/uploads/lost-found/demo_cover.jpg",
    "isPinned": false,
    "isFound": false,
    "foundAt": null,
    "createdAt": "2026-02-01T14:00:00.000Z",
    "updatedAt": "2026-02-01T14:00:00.000Z"
  },
  "message": "创建成功"
}
```

---

### 4. 更新走失 / 领养信息

- **接口**: `PUT /lost-found/:id`
- **权限**: ✅ 需要登录
- **说明**: 只有发布者或管理员可以更新

**路径参数**:

| 参数 | 类型   | 必填 | 说明        |
| ---- | ------ | ---- | ----------- |
| id   | number | 是   | 走失信息 ID |

**请求体**:

| 字段         | 类型     | 必填 | 说明                                   |
| ------------ | -------- | ---- | -------------------------------------- |
| petId        | number   | 否   | 宠物 ID；切换为手动宠物时传 `null`     |
| petName      | string   | 否   | 手动宠物名称                           |
| petCategory  | string   | 否   | 手动宠物类别                           |
| petBreed     | string   | 否   | 手动宠物品种                           |
| recordType   | string   | 否   | 记录类型：`LOST`=走失，`ADOPTION`=领养 |
| contactName  | string   | 否   | 联系人姓名（2-20 字）                  |
| contactPhone | string   | 否   | 联系电话（11 位手机号）                |
| description  | string   | 否   | 描述（10-500 字）                      |
| images       | string[] | 否   | 图片 URL 列表（最多 9 张）             |
| video        | string   | 否   | 视频 URL                               |
| videoCover   | string   | 否   | 视频封面图 URL                         |
| isFound      | boolean  | 否   | 是否已找回，仅 `LOST` 记录生效         |

**请求示例**:

```json
{
  "recordType": "LOST",
  "contactName": "王五",
  "description": "更新描述信息",
  "images": ["/uploads/lost-found/3.jpg"],
  "video": "/uploads/lost-found/updated.mp4",
  "videoCover": "/uploads/lost-found/updated_cover.jpg"
}
```

**响应示例**:

```json
{
  "code": 0,
  "data": {
    "id": 1,
    "petId": 10,
    "recordType": "LOST",
    "contactName": "王五",
    "description": "更新描述信息",
    "images": ["/uploads/lost-found/3.jpg"],
    "video": "/uploads/lost-found/updated.mp4",
    "videoCover": "/uploads/lost-found/updated_cover.jpg",
    "updatedAt": "2026-02-02T10:00:00.000Z"
  },
  "message": "更新成功"
}
```

---

### 5. 设置/取消置顶

- **接口**: `PATCH /lost-found/:id/pin`
- **权限**: ✅ 需要登录 🎭 管理员专用
- **说明**: 切换走失信息的置顶状态，置顶记录在列表中优先显示

**路径参数**:

| 参数 | 类型   | 必填 | 说明        |
| ---- | ------ | ---- | ----------- |
| id   | number | 是   | 走失信息 ID |

**响应示例**:

```json
{
  "code": 0,
  "data": {
    "id": 1,
    "isPinned": true,
    "updatedAt": "2026-02-02T10:00:00.000Z"
  },
  "message": "置顶成功"
}
```

---

### 6. 标记已找回

- **接口**: `PATCH /lost-found/:id/found`
- **权限**: ✅ 需要登录
- **说明**:
  - 只有发布者或管理员可以标记
  - 只能标记一次，重复操作会返回错误
  - 仅 `recordType=LOST` 的记录允许标记已找回

**路径参数**:

| 参数 | 类型   | 必填 | 说明        |
| ---- | ------ | ---- | ----------- |
| id   | number | 是   | 走失信息 ID |

**响应示例**:

```json
{
  "code": 0,
  "data": {
    "id": 1,
    "isFound": true,
    "foundAt": "2026-02-03T15:30:00.000Z",
    "updatedAt": "2026-02-03T15:30:00.000Z"
  },
  "message": "标记成功"
}
```

**错误响应** (已标记过):

```json
{
  "code": 3603,
  "message": "该信息已标记为找回，无需重复操作",
  "error": "LOST_FOUND_ALREADY_FOUND"
}
```

**错误响应** (领养记录不支持):

```json
{
  "code": 3606,
  "message": "领养信息不支持标记已找回",
  "error": "BUSINESS_ERROR"
}
```

---

### 7. 删除走失信息

- **接口**: `DELETE /lost-found/:id`
- **权限**: ✅ 需要登录
- **说明**: 只有发布者或管理员可以删除（软删除）

**路径参数**:

| 参数 | 类型   | 必填 | 说明        |
| ---- | ------ | ---- | ----------- |
| id   | number | 是   | 走失信息 ID |

**响应示例**:

```json
{
  "code": 0,
  "data": null,
  "message": "删除成功"
}
```

---

### 8. 获取走失 / 领养评论列表

- **接口**: `GET /lost-found/:id/comments`
- **权限**: 🌐 公开接口
- **说明**: 获取指定走失 / 领养信息下的评论列表，支持分页；返回顶层评论及其回复

**路径参数**:

| 参数 | 类型   | 必填 | 说明            |
| ---- | ------ | ---- | --------------- |
| id   | number | 是   | 走失招领信息 ID |

**查询参数**:

| 参数     | 类型   | 必填 | 说明              |
| -------- | ------ | ---- | ----------------- |
| page     | number | 否   | 页码，默认 1      |
| pageSize | number | 否   | 每页数量，默认 10 |

**响应示例**:

```json
{
  "code": 0,
  "data": [
    {
      "id": 101,
      "lostFoundId": 1,
      "userId": 8,
      "content": "今天下午在附近看到了很像的狗狗",
      "parentId": null,
      "likeCount": 0,
      "createdAt": "2026-04-14T09:20:00.000Z",
      "user": {
        "id": 8,
        "nickname": "热心市民",
        "avatar": "/uploads/users/avatar_8.jpg"
      },
      "replies": [
        {
          "id": 102,
          "lostFoundId": 1,
          "userId": 1,
          "content": "谢谢，请问大概是在什么位置？",
          "parentId": 101,
          "likeCount": 0,
          "createdAt": "2026-04-14T09:25:00.000Z",
          "user": {
            "id": 1,
            "nickname": "张三",
            "avatar": "/uploads/users/avatar_1.jpg"
          }
        }
      ]
    }
  ],
  "pagination": {
    "total": 1,
    "page": 1,
    "pageSize": 10,
    "limit": 10,
    "totalPages": 1
  },
  "message": "Success"
}
```

---

### 9. 发表评论 / 回复走失评论

- **接口**: `POST /lost-found/:id/comments`
- **权限**: ✅ 需要登录
- **说明**: 为走失 / 领养详情新增评论，传 `parentId` 时表示回复某条评论

**路径参数**:

| 参数 | 类型   | 必填 | 说明            |
| ---- | ------ | ---- | --------------- |
| id   | number | 是   | 走失招领信息 ID |

**请求体**:

| 字段     | 类型   | 必填 | 说明                    |
| -------- | ------ | ---- | ----------------------- |
| content  | string | 是   | 评论内容，最多 1000 字  |
| parentId | number | 否   | 父评论 ID，用于回复评论 |

**请求示例**:

```json
{
  "content": "我在张江路附近见过一只很像的狗狗",
  "parentId": 101
}
```

**响应示例**:

```json
{
  "code": 0,
  "data": {
    "id": 103,
    "lostFoundId": 1,
    "userId": 12,
    "content": "我在张江路附近见过一只很像的狗狗",
    "parentId": 101,
    "likeCount": 0,
    "createdAt": "2026-04-14T10:00:00.000Z",
    "user": {
      "id": 12,
      "nickname": "爱宠人士",
      "avatar": "/uploads/users/avatar_12.jpg"
    }
  },
  "message": "评论成功"
}
```

**错误响应** (父评论不存在):

```json
{
  "success": false,
  "statusCode": 404,
  "message": "父评论不存在"
}
```

---

### 错误码

| 错误码 | 说明                             |
| ------ | -------------------------------- |
| 3601   | 宠物不存在或已被删除             |
| 3602   | 您没有权限操作此信息             |
| 3603   | 该信息已标记为找回，无需重复操作 |
| 3604   | 描述信息不能超过500个字符        |
| 3605   | 请输入正确的手机号码             |
| 3606   | 领养信息不支持标记已找回         |

---

### 前端调用示例

```typescript
import {
  getLostFoundListApi,
  createLostFoundApi,
  updateLostFoundApi,
  deleteLostFoundApi,
  toggleLostFoundPinApi,
  markLostFoundAsFoundApi
} from '@/api-new/lost-found'

// 获取未找回的走失信息
const list = await getLostFoundListApi({
  recordType: 'LOST',
  isFound: false,
  page: 1,
  pageSize: 20
})

// 获取领养信息
const adoptionList = await getLostFoundListApi({
  recordType: 'ADOPTION',
  page: 1,
  pageSize: 20
})

// 创建领养信息
await createLostFoundApi({
  petId: 10,
  recordType: 'ADOPTION',
  contactName: '李四',
  contactPhone: '13900139000',
  description: '金毛犬旺财已绝育，疫苗齐全，希望寻找稳定领养家庭'
})

// 标记已找回
await markLostFoundAsFoundApi(1)

// 管理员 - 置顶
await toggleLostFoundPinApi(1)

// 删除
await deleteLostFoundApi(1)
```

---

### 业务规则

1. **宠物验证**:
   - 创建时必须提供有效的宠物 ID
   - 普通用户只能发布自己的宠物
   - 管理员可以发布任何宠物

2. **记录类型规则**:
   - `recordType=LOST` 表示走失信息，可标记已找回
   - `recordType=ADOPTION` 表示领养信息，不支持标记已找回
   - 列表页可通过 `recordType` 精确筛选走失或领养内容

3. **权限控制**:
   - 更新：只有发布者或管理员可以操作
   - 删除：只有发布者或管理员可以操作
   - 置顶：仅管理员可以操作
   - 标记找回：发布者或管理员可以操作，仅限走失记录

4. **状态限制**:
   - 标记找回后不能重复标记
   - 领养记录会始终保持 `isFound=false`
   - 删除为软删除，数据不会物理删除

5. **排序规则**:
   - 置顶记录优先显示
   - 按创建时间倒序排列（最新的在前）

---

**文档最后更新时间:** 2026-04-14

---

## Wallet 模块

钱包管理相关接口

### 移动端接口

| HTTP 方法 | 路径                      | 描述             | 权限 |
| --------- | ------------------------- | ---------------- | ---- |
| GET       | /shop/wallet              | 获取钱包概况     | ✅   |
| GET       | /shop/wallet/balance      | 获取钱包余额     | ✅   |
| GET       | /shop/wallet/transactions | 获取钱包交易明细 | ✅   |
| GET       | /shop/wallet/stats        | 获取收益统计     | ✅   |
| GET       | /shop/wallet/recharges/config | 获取充值配置 | ✅ |
| POST      | /shop/wallet/recharges | 创建支付宝充值 | ✅ |
| GET       | /shop/wallet/recharges | 获取充值记录 | ✅ |
| GET       | /shop/wallet/recharges/:id | 获取本人充值详情并确认支付状态 | ✅ |
| GET       | /shop/wallet/withdrawals/config | 获取提现配置 | ✅ |
| POST      | /shop/wallet/withdrawals | 创建支付宝提现 | ✅ |
| GET       | /shop/wallet/withdrawals | 获取提现记录 | ✅ |
| GET       | /shop/wallet/withdrawals/:id | 获取本人提现详情 | ✅ |

#### 获取钱包概况

**端点:** `GET /shop/wallet`

**描述:** 获取当前用户的钱包概况，包括可用余额和待审核余额

**响应示例:**

```json
{
  "success": true,
  "data": {
    "balance": 100.5,
    "pendingBalance": 50.0
  }
}
```

#### 获取钱包余额

**端点:** `GET /shop/wallet/balance`

**描述:** 获取当前用户的钱包余额（同概况接口）

**响应示例:**

```json
{
  "success": true,
  "data": {
    "balance": 100.5,
    "pendingBalance": 50.0
  }
}
```

#### 获取钱包交易明细

**端点:** `GET /shop/wallet/transactions`

**描述:** 获取当前用户的钱包交易明细列表，支持分页和筛选

**查询参数:** | 参数 | 类型 | 必填 | 描述 | |------|------|------|------| | page | number | 否 | 页码（默认 1） | | limit | number | 否 | 每页数量（默认 10，最大 100） | | type | string | 否 | 交易类型（income/expense/freeze/unfreeze） | | status | string | 否 | 状态（pending/approved/rejected） | | relatedType | string | 否 | 来源（order/refund/recharge/withdraw/charity/adjustment） |

**响应示例:**

```json
{
  "data": [
    {
      "id": 1,
      "userId": 10,
      "type": "income",
      "amount": 50.0,
      "balanceBefore": 0.0,
      "balanceAfter": 50.0,
      "relatedType": "order",
      "relatedId": 100,
      "status": "pending",
      "remark": "用户发布商品销售结算（成交¥100.00，手续费¥5.00）",
      "relatedProducts": [
        {
          "productId": 501,
          "productName": "二手猫窝",
          "productImage": "/uploads/cat-bed-1.png",
          "skuName": "默认规格",
          "quantity": 1,
          "price": 100.0
        }
      ],
      "createdAt": "2026-02-10T10:00:00.000Z"
    }
  ],
  "total": 1,
  "page": 1,
  "limit": 10
}
```

**字段说明:**

- `relatedProducts`: 当流水来自用户发布商品销售结算时，返回当前登录用户对应的商品列表，前端可直接展示并跳转商品详情，无需再请求订单详情
- 真实提现流水会附加 `withdrawalStatus`、`withdrawalNo`；历史 `relatedType=withdraw` 若没有提现实体，会附加 `historicalAdjustment=true`，按历史平台调整展示

#### 获取收益统计

**端点:** `GET /shop/wallet/stats`

**描述:** 获取当前用户的钱包摘要。字段名兼容已发布客户端，但含义按下述口径固定。

**字段说明:**

- `available`: 当前可提现余额，即 `users.balance`
- `pending`: 二手订单完成后尚未结算的卖家净收入，即待到账金额
- `total`: 累计二手收益，只统计当前用户作为卖家的 `second_hand` 订单结算流水，且必须为 `type=income`、`relatedType=order`、`status in (pending, approved)`；退款、充值、平台调整、普通订单、拒绝结算和提现均不计入
- `frozen`: 已提交但尚未进入终态的提现冻结金额

**响应示例:**

```json
{
  "success": true,
  "data": {
    "available": 100.5,
    "pending": 50.0,
    "total": 150.5,
    "frozen": 20.0
  }
}
```

#### 支付宝主动充值

`GET /shop/wallet/recharges/config` 返回当前充值开关、金额范围和客户端可展示的快捷金额：

```json
{
  "enabled": true,
  "minAmount": 1.0,
  "maxAmount": 50000.0,
  "presets": [10.0, 50.0, 100.0, 200.0],
  "unavailableReason": null
}
```

`POST /shop/wallet/recharges` 必须携带 `Idempotency-Key: <UUID v4>`，请求体中的 `amount` 必须是 `1.00` 至 `50000.00` 之间、最多两位小数的十进制字符串。同一用户使用同一幂等键和金额重试时返回原充值单与支付参数，不会创建重复充值单。

```json
{
  "amount": "50.00"
}
```

创建成功响应中的 `alipayOrderString` 供 Flutter 客户端调用支付宝 APP SDK：

```json
{
  "id": 21,
  "rechargeNo": "RC1785480000000A1B2C3D4",
  "amount": 50.0,
  "status": "pending",
  "paymentNo": "PAY1785480000000A1B2C3D4",
  "alipayOrderString": "app_id=...&sign=...",
  "expiredAt": "2026-07-31T09:15:00.000Z",
  "paidAt": null,
  "failureMessage": null,
  "createdAt": "2026-07-31T09:00:00.000Z",
  "updatedAt": "2026-07-31T09:00:00.000Z"
}
```

- 客户端不得把支付宝 SDK 的本地成功结果直接视为到账；必须通过 `GET /shop/wallet/recharges/:id` 获取服务端充值单状态。
- 支付成功回调与主动查单共用同一事务入账逻辑：锁定支付单、充值单和用户，增加 `users.balance`，并创建 `income + recharge + approved` 钱包流水；重复回调不会重复入账。
- 充值进入现有可用余额，不单独划分不可提现余额，因此到账后既可消费也可提现。
- 状态：`pending` 待支付确认、`succeeded` 已到账、`failed` 充值失败、`closed` 支付单已关闭。

#### 充值记录和详情

- `GET /shop/wallet/recharges?page=1&limit=10&status=`：按创建时间倒序返回当前用户的充值记录；`status` 可传 `pending/succeeded/failed/closed`。
- `GET /shop/wallet/recharges/:id`：只允许读取当前用户自己的充值单；待确认记录会先向支付渠道主动查单，再返回最新状态。
- 列表与详情不会返回可重复使用的 `alipayOrderString`；支付参数只在创建充值时返回。

#### 支付宝提现配置

`GET /shop/wallet/withdrawals/config` 返回当前可提现余额、最低金额、单笔上限、今日剩余额度及是否存在活跃提现。`enabled` 只有在 `system_configs.wallet_withdrawal.businessEnabled=true`、支付宝转账配置完整且 `WALLET_PII_ENCRYPTION_KEY` 可用时才为 `true`；缺少密钥、公钥或任一证书时钱包读取不受影响，但提现关闭，并通过 `unavailableReason` 返回可展示原因。

```json
{
  "enabled": false,
  "availableBalance": 100.0,
  "minAmount": 1.0,
  "maxAmountPerRequest": 50000.0,
  "remainingDailyAmount": 50000.0,
  "hasActiveWithdrawal": false,
  "unavailableReason": "支付宝提现暂未配置"
}
```

#### 创建支付宝提现

`POST /shop/wallet/withdrawals` 必须携带 `Idempotency-Key: <UUID v4>`。同一用户重试同一幂等键会返回原提现单，不会重复冻结余额。

```json
{
  "amount": "100.00",
  "alipayAccount": "user@example.com",
  "payeeRealName": "张三"
}
```

- `amount` 必须是正的十进制字符串，最多两位小数。
- 支付宝账号长度为 5-128，实名姓名长度为 2-64；首尾空白会去除，控制字符会被拒绝。
- 申请事务内同时执行 `balance -= amount`、`withdrawalFrozenBalance += amount`，并创建提现单、钱包流水和状态日志。
- 单日限额按 `Asia/Shanghai` 自然日累计 `pending_review/processing/succeeded`，排除 `rejected/failed`；同一用户只允许一笔 `pending_review/processing` 提现。
- 响应只返回脱敏账号和姓名，不返回密文或明文收款信息。

#### 提现记录和详情

- `GET /shop/wallet/withdrawals?page=1&limit=10&status=`：按创建时间倒序返回当前用户的提现记录。
- `GET /shop/wallet/withdrawals/:id`：只允许读取当前用户自己的提现详情。
- 状态：`pending_review` 审核中、`processing` 转账中、`succeeded` 已到账、`rejected` 已拒绝且余额已退回、`failed` 转账明确失败且余额已退回。

### 后台管理接口

| HTTP 方法 | 路径                                              | 描述               | 权限  |
| --------- | ------------------------------------------------- | ------------------ | ----- |
| GET       | /server-api/admin/wallet/transactions             | 获取钱包交易列表   | ✅ 🎭 |
| POST      | /server-api/admin/wallet/transactions/:id/approve | 审核通过           | ✅ 🎭 |
| POST      | /server-api/admin/wallet/transactions/:id/reject  | 审核拒绝           | ✅ 🎭 |
| GET       | /server-api/admin/wallet/withdrawals | 提现列表 | ✅ SUPER_ADMIN |
| GET       | /server-api/admin/wallet/withdrawals/:id | 提现详情 | ✅ SUPER_ADMIN |
| POST      | /server-api/admin/wallet/withdrawals/:id/approve | 审核并发起支付宝转账 | ✅ SUPER_ADMIN |
| POST      | /server-api/admin/wallet/withdrawals/:id/reject | 拒绝并退回余额 | ✅ SUPER_ADMIN |
| POST      | /server-api/admin/wallet/withdrawals/:id/reconcile | 查询支付宝状态 | ✅ SUPER_ADMIN |
| GET       | /server-api/admin/wallet/withdrawal-config | 获取提现规则 | ✅ SUPER_ADMIN |
| PUT       | /server-api/admin/wallet/withdrawal-config | 更新提现规则 | ✅ SUPER_ADMIN |

#### 获取钱包交易列表

**端点:** `GET /server-api/admin/wallet/transactions`

**描述:** 获取钱包交易列表，包含用户等关联信息，支持分页和筛选

**查询参数:**

| 参数   | 类型   | 必填 | 描述                                          |
| ------ | ------ | ---- | --------------------------------------------- |
| page   | number | 否   | 页码（默认 1）                                |
| limit  | number | 否   | 每页数量（默认 10）                           |
| userId | number | 否   | 用户 ID 筛选                                  |
| type   | string | 否   | 交易类型（income/expense/freeze/unfreeze）    |
| status | string | 否   | 状态（pending/approved/rejected）             |

**响应示例:**

```json
{
  "items": [
    {
      "id": 1,
      "userId": 10,
      "user": {
        "id": 10,
        "phone": "13800138000"
      },
      "type": "income",
      "amount": 50.0,
      "balanceBefore": 0.0,
      "balanceAfter": 50.0,
      "relatedType": "order",
      "relatedId": 100,
      "status": "pending",
      "remark": "二手商品销售收入",
      "createdAt": "2026-02-10T10:00:00.000Z",
      "waitingDays": 3,
      "isOverdue": false
    }
  ],
  "total": 1,
  "page": 1,
  "limit": 10
}
```

**字段说明:**

- `waitingDays`: 等待天数
- `isOverdue`: 是否超期（超过 7 天）

#### 审核通过

**端点:** `POST /server-api/admin/wallet/transactions/:id/approve`

**描述:** 审核通过待审核的交易，将待审核余额转入可用余额

**路径参数:** | 参数 | 类型 | 必填 | 描述 | |------|------|------|------| | id | number | 是 | 交易 ID |

**请求体:**

```json
{
  "remark": "审核通过备注（可选）"
}
```

**响应示例:**

```json
{
  "id": 1,
  "userId": 10,
  "type": "income",
  "amount": 50.0,
  "status": "approved",
  "reviewedAt": "2026-02-10T12:00:00.000Z",
  "reviewedBy": 1,
  "autoProcessed": false
}
```

#### 审核拒绝

**端点:** `POST /server-api/admin/wallet/transactions/:id/reject`

**描述:** 审核拒绝待审核的交易，扣减待审核余额并冻结

**路径参数:** | 参数 | 类型 | 必填 | 描述 | |------|------|------|------| | id | number | 是 | 交易 ID |

**请求体:**

```json
{
  "reason": "审核拒绝原因（必填）"
}
```

**响应示例:**

```json
{
  "id": 1,
  "userId": 10,
  "type": "income",
  "amount": 50.0,
  "status": "rejected",
  "frozenAmount": 50.0,
  "rejectReason": "审核拒绝原因",
  "reviewedAt": "2026-02-10T12:00:00.000Z",
  "reviewedBy": 1,
  "autoProcessed": false
}
```

#### 支付宝提现后台审核与对账

- 列表支持 `withdrawalNo`、`userId`、`phone`、`status`、`startDate`、`endDate`、`page`、`limit`。
- `approve` 只接受 `pending_review`。服务先检查业务开关、PII 密钥和支付宝转账配置，再在事务内保存稳定 `outBizNo` 并转为 `processing`；随后离开数据库事务调用 `alipay.fund.trans.uni.transfer`。
- 明确成功时扣减 `withdrawalFrozenBalance` 并转为 `succeeded`；明确失败时扣减冻结并完整退回 `balance`；网络超时或结果不明确时保持 `processing` 和冻结资金。
- `reconcile` 只接受 `processing`，始终使用原 `outBizNo` 调用 `alipay.fund.trans.common.query`。系统每 10 分钟自动扫描并对账，任何路径都不会生成第二个转账业务单号。
- `reject` 只接受 `pending_review`，拒绝原因长度 2-500，资金完整退回。
- 提现状态日志只追加；Admin 响应只展示脱敏账号、姓名、必要支付宝业务标识和脱敏失败信息。

提现规则配置请求：

```json
{
  "businessEnabled": false,
  "minAmount": "1.00",
  "maxAmountPerRequest": "50000.00",
  "maxAmountPerDay": "50000.00"
}
```

证书、私钥和 PII 密钥只允许通过部署环境提供，不通过该接口或 `system_configs` 保存。证书模式必须同时提供 `ALIPAY_APP_CERT_PATH`、`ALIPAY_PUBLIC_CERT_PATH`、`ALIPAY_ROOT_CERT_PATH`；只提供部分证书会直接禁用支付宝能力，不会降级。`ALIPAY_TRANSFER_SCENE_NAME` 必须配置为支付宝商家平台已申报的转账场景名称；本项目的卖家货款提现申报并配置为 `业务结算`，并按支付宝字段说明配置 `ALIPAY_TRANSFER_SCENE_REPORT_INFO_TYPE=结算款项名称`、`ALIPAY_TRANSFER_SCENE_REPORT_INFO_CONTENT=二手商品销售货款`。上述任一项缺失时提现关闭。真实转账前必须在支付宝开放平台确认应用已开通“转账到支付宝账户”相关产品权限，并核对平台单笔/单日额度。

#### 提现业务错误码

| 错误码 | 含义 |
| --- | --- |
| `3030` | 提现业务关闭或支付宝/PII 配置不完整 |
| `3031` | 提现金额格式或最低金额不合法 |
| `3032` | 超过单笔或单日限额 |
| `3033` | 已存在审核中或转账中的提现 |
| `3034` | 提现单不存在或不属于当前用户 |
| `3035` | 当前状态不允许该操作 |
| `3002` | 可提现余额不足 |

### 数据类型

#### WalletTransactionType（交易类型）

| 值       | 描述 |
| -------- | ---- |
| income   | 收入 |
| expense  | 支出 |
| freeze   | 冻结 |
| unfreeze | 解冻 |

#### WalletTransactionStatus（交易状态）

| 值       | 描述   |
| -------- | ------ |
| pending  | 待审核 |
| approved | 已审核 |
| rejected | 已拒绝 |

#### RelatedType（关联类型）

| 值       | 描述 |
| -------- | ---- |
| order    | 订单 |
| refund   | 退款 |
| recharge | 充值 |
| withdraw | 提现 |
| charity | 公益捐款 |
| adjustment | 平台余额调整 |

### 业务规则

1. **余额管理**:
   - 可用余额 (`balance`)：可以用于提现或消费
   - 待到账 (`pendingBalance`)：二手卖家净收益等待结算的金额
   - 提现中金额 (`withdrawalFrozenBalance`)：提现申请已预占、尚未进入终态的金额

2. **交易类型说明**:
   - `income` (收入)：二手商品销售收入，直接增加待审核余额
   - `expense` (支出)：用户消费，减少可用余额
   - 真实支付宝提现记录为 `expense + withdraw`；其业务状态由关联提现单提供
   - `adjustment` 表示管理员余额调整，历史无提现实体的 `withdraw` 也按历史平台调整展示

3. **二手商品销售流程**:

   ```
   买家下单 → 买家付款 → 买家确认收货/满10天自动确认 → 系统创建结算记录
                                                      ↓
                                          type: income (收入)
                                          status: pending (待审核)
                                                      ↓
                                          管理员审核（或7天自动审核）
                                                      ↓
                                          ├─ 审核通过：pendingBalance → balance
                                          └─ 审核拒绝：扣除 pendingBalance
   ```

4. **审核流程**:
   - 待审核交易创建后，等待管理员审核
   - 超过 7 天自动通过（定时任务每小时执行）
   - 管理员可以提前手动审核
   - 审核通过：`pendingBalance → balance`（待审核余额 → 可用余额）
   - 审核拒绝：扣减 `pendingBalance`，记录 `frozenAmount` 和 `rejectReason`

5. **余额变化示例** (用户发布商品销售，手续费 5%): | 阶段 | balance | pendingBalance | 说明 | |------|---------|----------------|------| | 初始 | 100.00 | 0.00 | 用户原有余额 | | 买家付款 | 100.00 | 0.00 | 仅订单进入待发货/待收货，不创建结算 | | 确认收货 | 100.00 | 95.00 | 创建 INCOME 类型交易，按净收入 +95 到待审核余额 | | 审核通过 | 195.00 | 0.00 | 待审核余额转入可用余额 | | 审核拒绝 | 100.00 | 0.00 | 扣除待审核余额（资金退回平台） |

6. **权限控制**:
   - 移动端接口：需要用户登录
   - 后台管理接口：需要管理员角色（SUPER_ADMIN 或 HOSPITAL_ADMIN）

7. **数据一致性**:
   - 使用数据库事务确保原子性
   - 使用行锁防止并发更新
   - 余额验证防止超额扣减

8. **定时任务**:
   - 自动审核超过 7 天的待审核交易
   - 执行频率：每小时一次
   - 记录执行日志

---

## Community 模块

社区内容、社区公开资料与独立关注关系管理模块。

### 帖子与互动接口

| HTTP 方法 | 路径                          | 描述                          | 权限 |
| --------- | ----------------------------- | ----------------------------- | ---- |
| GET       | /community/posts              | 获取帖子列表（关注流/推荐流） | ✅   |
| POST      | /community/posts              | 发布帖子                      | ✅   |
| GET       | /community/posts/:id          | 获取帖子详情                  | ✅   |
| PUT       | /community/posts/:id          | 编辑帖子                      | ✅   |
| DELETE    | /community/posts/:id          | 删除帖子                      | ✅   |
| GET       | /community/posts/user/:userId | 获取用户帖子列表              | ✅   |
| POST      | /community/posts/:id/like     | 点赞帖子                      | ✅   |
| DELETE    | /community/posts/:id/like     | 取消点赞帖子                  | ✅   |
| GET       | /community/posts/:id/comments | 获取顶层评论及其回复          | ✅   |
| POST      | /community/posts/:id/comments | 发表评论/回复                 | ✅   |
| DELETE    | /community/comments/:id       | 删除评论                      | ✅   |
| POST      | /community/comments/:id/like  | 点赞评论                      | ✅   |
| DELETE    | /community/comments/:id/like  | 取消点赞评论                  | ✅   |

编辑帖子时，只要请求中包含 `content`、`images`、`video`、`videoCover` 或 `tags` 中的任一字段，帖子审核状态就会重置为 `PENDING_REVIEW`。若编辑后的正文命中敏感词拒绝规则，状态为 `REJECTED`；审核通过前不会出现在公开信息流中。

### 社区资料接口

| HTTP 方法 | 路径                             | 描述             | 权限 |
| --------- | -------------------------------- | ---------------- | ---- |
| GET       | /community/users/:userId/profile | 获取社区公开资料 | ✅   |
| PUT       | /community/profile               | 更新我的社区资料 | ✅   |

### 关注关系接口

> 关注体系与好友体系完全独立。关注为单向关系，用于社区内容分发；好友体系继续仅服务聊天与私域沟通。

| HTTP 方法 | 路径                                | 描述         | 权限 |
| --------- | ----------------------------------- | ------------ | ---- |
| POST      | /community/users/:userId/follow     | 关注用户     | ✅   |
| DELETE    | /community/users/:userId/follow     | 取消关注用户 | ✅   |
| GET       | /community/users/:userId/followers  | 获取粉丝列表 | ✅   |
| GET       | /community/users/:userId/followings | 获取关注列表 | ✅   |

### 社区管理接口（Admin）

| HTTP 方法 | 路径                               | 描述           | 权限 |
| --------- | ---------------------------------- | -------------- | ---- |
| GET       | /admin/community/posts/pending     | 获取待审核帖子 | ✅   |
| POST      | /admin/community/posts/:id/approve | 审核通过帖子   | ✅   |
| POST      | /admin/community/posts/:id/reject  | 审核拒绝帖子   | ✅   |
| GET       | /admin/community/posts             | 获取已审核内容 | ✅   |
| PUT       | /admin/community/posts/:id/pin     | 置顶/取消置顶  | ✅   |
| PUT       | /admin/community/posts/:id/feature | 加精/取消加精  | ✅   |
| DELETE    | /admin/community/posts/:id         | 删除帖子       | ✅   |
| GET       | /admin/community/sensitive-words   | 获取敏感词列表 | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN |
| POST      | /admin/community/sensitive-words   | 新增敏感词     | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN |
| PUT       | /admin/community/sensitive-words/:id | 更新敏感词   | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN |
| DELETE    | /admin/community/sensitive-words/:id | 删除敏感词  | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN |
| POST      | /admin/community/sensitive-words/batch | 批量导入敏感词 | 🎭 SUPER_ADMIN, HOSPITAL_ADMIN |

启用的敏感词同时用于社区内容审核和用户昵称校验。社区内容根据 `severity` 执行标记、替换或拒绝；昵称命中任一等级均直接拒绝保存。更新或删除敏感词后 Server 会立即刷新内存缓存。

```typescript
interface SensitiveWord {
  id: number
  word: string
  severity: 1 | 2 | 3
  replacement?: string
  category?: string
  isActive: boolean
  createdAt: string
  updatedAt: string
}
```

### 数据结构

```typescript
interface CommunityPost {
  id: number
  userId: number
  user?: {
    id: number
    nickname: string
    avatar?: string
  }
  content: string
  images?: string[] // 最多 9 张图片，相对路径统一为 /uploads/...
  video?: string // 单个视频地址，相对路径统一为 /uploads/...
  videoCover?: string // 视频封面图地址，相对路径统一为 /uploads/...
  tags?: string[] // 标签保留原始名称，例如 '#宠物医疗'
  status: 'PENDING_REVIEW' | 'APPROVED' | 'REJECTED'
  likeCount: number
  commentCount: number
  viewCount: number
  isPinned: boolean
  isFeatured: boolean
  rejectReason?: string
  detectedSensitiveWords?: string[]
  createdAt: string
  updatedAt: string
}

interface CommunityComment {
  id: number
  postId: number
  userId: number
  content: string
  parentId: number | null
  likeCount: number
  isLiked: boolean
  user: {
    id: number
    nickname: string
    avatar?: string
  }
  replies: CommunityComment[]
  createdAt: string
  updatedAt: string
}

interface CommunityPublicProfile {
  user: {
    id: number
    username?: string
    nickname: string
    avatar?: string
    bio?: string
    coverImage?: string
    verified?: boolean
    createdAt?: string
  }
  stats: {
    postCount: number
    followerCount: number
    followingCount: number
  }
  relationship: {
    isSelf: boolean
    isFollowing: boolean
    isFollowedBy: boolean
    isMutualFollow: boolean
  }
}

interface FriendRelationshipSummary {
  isFriend: boolean
  outgoingPending: boolean
  incomingPending: boolean
}
```

### 业务规则

1. **关注与好友解耦**：
   - 关注：单向关系，仅服务社区内容流和公开关系展示
   - 好友：双向关系，仅服务聊天、备注、好友申请等私域能力

2. **互相关注**：
   - 当 A 关注 B 且 B 关注 A 时，`isMutualFollow = true`
   - 互相关注不自动转化为好友关系

3. **关注流规则**：
   - `GET /community/posts?type=following` 仅返回当前用户已关注对象的帖子
   - 关注流优先按置顶，其次按发布时间倒序

4. **资料隐私边界**：
   - 社区公开资料接口不返回手机号、邮箱等敏感字段
   - 社区页面仅消费 `username/nickname/avatar/bio/coverImage/createdAt` 等公开字段

5. **帖子媒体规则**：
   - 单条帖子最多上传 `9` 张图片，或上传 `1` 个视频
   - 视频地址支持 `mp4/mov/avi/wmv/webm/mpeg` 常见格式

6. **评论层级规则**：
   - `GET /community/posts/:id/comments` 的 `data` 仅包含 `parentId` 为空的顶层评论
   - 回复通过对应顶层评论的 `replies` 字段返回，不会同时作为顶层评论重复返回
   - 评论列表的分页和 `meta.total` 仅统计顶层评论

- `rnapp` 发帖时会先在前端本地抽取视频封面，并与视频文件通过同一个上传请求一并提交
- 带视频的帖子会额外返回 `videoCover` 字段，列表页、详情页和 Admin 审核页应优先使用该字段展示视频预览
- 图片与视频上传成功后统一返回 `/uploads/...` 相对路径，由 `rnapp` 和 `admin` 通过各自静态资源工具补全完整地址
- 帖子列表、详情页和 Admin 审核页使用同一份 `CommunityPost` 结构，避免媒体字段解释不一致

---

## Moderation 模块

UGC 举报与屏蔽治理接口。该模块用于满足 App Store Guideline 1.2 中“可举报内容、可屏蔽用户、后台及时处理”的要求，覆盖社区、走失 / 领养、活动和二手商品等公开内容。好友聊天使用 Friends 模块独立的聊天拉黑关系。

### 接口概览

#### RN App 用户端

| HTTP 方法 | 路径                                | 描述             | 权限 |
| --------- | ----------------------------------- | ---------------- | ---- |
| POST      | /moderation/reports                 | 提交 UGC 举报    | ✅   |
| POST      | /moderation/blocks                  | 屏蔽用户         | ✅   |
| DELETE    | /moderation/blocks/:blockedUserId   | 取消屏蔽用户     | ✅   |
| GET       | /moderation/blocks                  | 获取我的屏蔽列表 | ✅   |

#### Admin 管理端

| HTTP 方法 | 路径                                      | 描述             | 权限 |
| --------- | ----------------------------------------- | ---------------- | ---- |
| GET       | /admin/moderation/reports                 | 获取举报列表     | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF |
| GET       | /admin/moderation/reports/:id             | 获取举报详情     | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF |
| PATCH     | /admin/moderation/reports/:id/status      | 更新举报处理状态 | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF |
| POST      | /admin/moderation/reports/:id/actions     | 执行举报处理动作 | 🎭 SUPER_ADMIN / HOSPITAL_ADMIN / STAFF |

### 固定枚举

**举报目标类型 `targetType`**

```typescript
type ReportTargetType =
  | 'COMMUNITY_POST'
  | 'COMMUNITY_COMMENT'
  | 'LOST_FOUND_RECORD'
  | 'LOST_FOUND_COMMENT'
  | 'ACTIVITY_COMMENT'
  | 'ACTIVITY_VOTE_OPTION'
  | 'SECOND_HAND_PRODUCT'
  | 'CHAT_MESSAGE'
  | 'USER'
```

**举报原因 `reason`**

```typescript
type ReportReason =
  | 'HARASSMENT'
  | 'PORNOGRAPHY'
  | 'VIOLENCE'
  | 'FRAUD'
  | 'SPAM'
  | 'ILLEGAL'
  | 'MISINFORMATION'
  | 'OTHER'
```

**处理状态 `status`**

```typescript
type ReportStatus = 'PENDING' | 'PROCESSING' | 'RESOLVED' | 'REJECTED'
```

**处理动作 `action`**

```typescript
type ReportAction =
  | 'NONE'
  | 'CONTENT_REMOVED'
  | 'USER_WARNED'
  | 'USER_BLOCKED'
  | 'ACCOUNT_DISABLED'
```

### 1. 提交举报

- **路径**: `POST /moderation/reports`
- **权限**: 登录用户
- **说明**: 同一用户对同一目标存在 `PENDING` 或 `PROCESSING` 举报时，不重复创建，直接返回已有举报。

请求体：

```json
{
  "targetType": "COMMUNITY_POST",
  "targetId": 123,
  "reason": "SPAM",
  "description": "疑似广告刷屏"
}
```

响应示例：

```json
{
  "id": 1,
  "reporterId": 10,
  "targetType": "COMMUNITY_POST",
  "targetId": "123",
  "targetUserId": 20,
  "reason": "SPAM",
  "description": "疑似广告刷屏",
  "targetSnapshot": {
    "summary": "帖子正文摘要",
    "images": ["/uploads/community/a.jpg"],
    "author": {
      "id": 20,
      "nickname": "用户20",
      "avatar": null
    }
  },
  "status": "PENDING",
  "action": "NONE",
  "createdAt": "2026-07-03T10:00:00.000Z"
}
```

### 2. 屏蔽用户

- **路径**: `POST /moderation/blocks`
- **权限**: 登录用户
- **说明**: 禁止自我屏蔽；同一用户对同一目标只能屏蔽一次，重复调用返回已有记录。

请求体：

```json
{
  "blockedUserId": 20,
  "reason": "举报后屏蔽"
}
```

### 3. 取消屏蔽用户

- **路径**: `DELETE /moderation/blocks/:blockedUserId`
- **权限**: 登录用户

### 4. 获取我的屏蔽列表

- **路径**: `GET /moderation/blocks`
- **权限**: 登录用户

响应示例：

```json
[
  {
    "id": 1,
    "blockerId": 10,
    "blockedUserId": 20,
    "reason": "举报后屏蔽",
    "blockedAt": "2026-07-03T10:00:00.000Z",
    "createdAt": "2026-07-03T10:00:00.000Z",
    "blockedUser": {
      "id": 20,
      "username": "pet_friend",
      "nickname": "用户20",
      "avatar": null
    }
  }
]
```

列表按屏蔽时间倒序返回。`blockedAt` 是客户端展示使用的屏蔽时间，`createdAt` 为兼容旧客户端保留；即使用户关联暂时不可用，接口仍会使用 `blockedUserId` 返回可解除屏蔽的占位用户摘要。

### 5. 获取举报列表（Admin）

- **路径**: `GET /admin/moderation/reports`
- **权限**: `SUPER_ADMIN` / `HOSPITAL_ADMIN` / `STAFF`

查询参数：

| 参数       | 类型   | 必填 | 说明 |
| ---------- | ------ | ---- | ---- |
| page       | number | 否   | 页码，默认 1 |
| pageSize   | number | 否   | 每页数量，默认 20，最大 100 |
| status     | string | 否   | `PENDING` / `PROCESSING` / `RESOLVED` / `REJECTED` |
| targetType | string | 否   | 举报目标类型 |
| reason     | string | 否   | 举报原因 |
| startTime  | string | 否   | 创建时间起点 |
| endTime    | string | 否   | 创建时间终点 |

响应示例：

```json
{
  "data": [
    {
      "id": 1,
      "targetType": "COMMUNITY_POST",
      "targetId": "123",
      "reason": "SPAM",
      "status": "PENDING",
      "action": "NONE",
      "isOverdue": false,
      "reporter": {
        "id": 10,
        "nickname": "举报人"
      },
      "targetUser": {
        "id": 20,
        "nickname": "被举报用户"
      },
      "createdAt": "2026-07-03T10:00:00.000Z"
    }
  ],
  "total": 1,
  "page": 1,
  "pageSize": 20,
  "totalPages": 1
}
```

### 6. 获取举报详情（Admin）

- **路径**: `GET /admin/moderation/reports/:id`
- **权限**: `SUPER_ADMIN` / `HOSPITAL_ADMIN` / `STAFF`
- **说明**: 返回举报记录、举报人、被举报用户、处理人和目标快照。

### 7. 更新处理状态（Admin）

- **路径**: `PATCH /admin/moderation/reports/:id/status`
- **权限**: `SUPER_ADMIN` / `HOSPITAL_ADMIN` / `STAFF`

请求体：

```json
{
  "status": "PROCESSING",
  "remark": "已进入人工复核"
}
```

### 8. 执行处理动作（Admin）

- **路径**: `POST /admin/moderation/reports/:id/actions`
- **权限**: `SUPER_ADMIN` / `HOSPITAL_ADMIN` / `STAFF`

请求体：

```json
{
  "action": "CONTENT_REMOVED",
  "remark": "内容违反社区规范，已下架"
}
```

动作说明：

| action | 效果 |
| ------ | ---- |
| `NONE` | 标记举报无效，状态更新为 `REJECTED` |
| `CONTENT_REMOVED` | 对举报目标执行软删除 / 下架 / 隐藏消息，状态更新为 `RESOLVED` |
| `USER_WARNED` | 记录警告处理动作，状态更新为 `RESOLVED` |
| `USER_BLOCKED` | 代表举报人屏蔽被举报用户，状态更新为 `RESOLVED` |
| `ACCOUNT_DISABLED` | 禁用被举报用户账号，状态更新为 `RESOLVED` |

### 业务规则

1. 举报目标快照由后端解析并保存，前端不得提交作者、摘要或图片快照。
2. 社区、走失 / 领养、活动、二手商品等列表和评论接口默认过滤当前登录用户已屏蔽用户的内容。
3. Moderation 屏蔽不控制好友聊天；好友聊天拉黑使用 `/friends/chat-blocks`，仅作用于好友关系互动。
4. Moderation 屏蔽仅作用于 UGC 和公开社交内容，不影响好友聊天、医生问诊、订单、预约、售后等链路。
5. Admin “举报处理”页面挂在社区管理下，使用上述 Admin 接口处理所有 UGC 类型。

---

**文档最后更新时间:** 2026-08-13

## 医生端咨询会话实时同步

### 获取医生咨询会话

- **路径**: `GET /chat/doctor/sessions`
- **权限**: `DOCTOR`，服务端仅返回当前登录医生的会话
- **查询参数**: `status`（`PAID` / `EXPIRED`）、`page`、`limit`
- **用途**: 医生端冷启动、前后台恢复及 Socket 重连时同步咨询列表

每个 `sessions` 项包含用户头像 `userAvatar`、`lastMessage` 和 `unreadCount`。`userAvatar`
为空字符串时表示用户未设置头像；`lastMessage` 为消息对象，
至少包含 `id`、`conversationId`、`senderId`、`receiverId`、`content`、`type`、
`isAutoReply`、`isRead`、`createdAt`；响应根级 `unreadCount` 是当前医生的总未读数。

```json
{
  "code": 0,
  "data": {
    "sessions": [
      {
        "conversationId": "session-uuid",
        "userAvatar": "/uploads/avatars/user-12.jpg",
        "lastMessage": {
          "id": 101,
          "content": "宠物刚刚吐了",
          "type": "TEXT",
          "createdAt": "2026-07-28T10:00:00.000Z"
        },
        "unreadCount": 2
      }
    ],
    "unreadCount": 2,
    "pagination": {
      "total": 1,
      "page": 1,
      "pageSize": 20,
      "totalPages": 1
    }
  },
  "message": "Success"
}
```

### 实时事件与已读

- 登录后连接聊天 Socket，鉴权成功后服务端自动加入 `chat:doctor:<doctorId>` 个人房间
- 新消息事件: `chat:message:new`，载荷为完整消息对象
- 会话延长事件: `chat:session:extended`，服务端会向会话房间、用户个人房间和医生个人房间广播最新 `serviceEndAt`
- 标记会话已读: `PUT /chat/conversations/:conversationId/read`
- 客户端进入后台时断开，恢复前台时先刷新会话列表再重新连接

### 医生主动延长咨询时间

- **路径**: `POST /chat/doctor/sessions/:conversationId/extensions`
- **权限**: `DOCTOR`，服务端仅允许当前登录医生操作本人会话
- **请求体**:

```json
{
  "minutes": 15,
  "reason": "需要补充说明检查结果",
  "idempotencyKey": "uuid"
}
```

- `minutes` 仅支持 `5`、`10`、`15`、`30` 分钟；每个会话累计延长时间不设上限
- 仅允许 `PAID` 且当前尚未到期的会话；已过期会话不会重新开启
- 延长不修改订单金额、原始套餐时长或医生收入，只同步会话和订单的 `serviceEndAt`
- 同一 `idempotencyKey` 重试会返回同一延长结果，不会重复累加时间

**响应示例**:

```json
{
  "extensionId": 18,
  "conversationId": "session-uuid",
  "userId": 12,
  "doctorId": 7,
  "orderId": 301,
  "extensionMinutes": 15,
  "previousServiceEndAt": "2026-08-24T10:30:00.000Z",
  "serviceEndAt": "2026-08-24T10:45:00.000Z",
  "status": "PAID",
  "extendedAt": "2026-08-24T10:20:00.000Z"
}
```

## 医生端咨询用户健康档案

以下接口仅允许 `DOCTOR` 访问。服务端使用 JWT 中的医生 ID 和
`conversationId` 校验咨询归属，不接受客户端传入 `userId` 作为授权依据；所有接口均为只读。

### 1. 获取咨询用户及宠物档案

- **路径**: `GET /chat/doctor/sessions/:conversationId/patient`
- **权限**: `DOCTOR`，且会话必须属于当前医生
- **响应**: 用户基础信息、`petCount` 和宠物列表。每只宠物的 `healthStats`
  包含 `vaccine`、`deworming`、`checkup` 三类汇总，每类均返回 `count`、
  `lastAt`、`nextAt`。为兼容旧客户端，`vaccination` 字段继续返回疫苗汇总。

```json
{
  "healthStats": {
    "vaccine": { "count": 3, "lastAt": "2026-01-10", "nextAt": "2027-01-10" },
    "deworming": { "count": 2, "lastAt": "2026-06-01", "nextAt": "2026-09-01" },
    "checkup": { "count": 1, "lastAt": "2026-03-15", "nextAt": "2027-03-15" }
  },
  "vaccination": { "count": 3, "lastAt": "2026-01-10", "nextAt": "2027-01-10" }
}
```

### 2. 获取当前医患关系的历史咨询

- **路径**: `GET /chat/doctor/sessions/:conversationId/history`
- **查询参数**: `page`（默认 1）、`pageSize`（默认 20，最大 50）
- **数据范围**: 只返回当前会话之前、同一用户与当前医生之间的 `PAID` / `EXPIRED` 持久化会话
- **响应项目**: `conversationId`、服务项目、服务时间、状态、`messageCount` 和 `lastMessage`
- **权限校验**: 服务端从当前 `conversationId` 推导用户，不接受客户端传入 `userId`

### 3. 获取历史咨询的只读消息

- **路径**: `GET /chat/doctor/sessions/:conversationId/history/:historyConversationId/messages`
- **查询参数**: `page`（默认 1）、`pageSize`（默认 50，最大 100）
- **分页方向**: 第 1 页是最新一页，每页内部按时间正序返回；客户端继续请求下一页并向列表顶部插入
- **数据规则**: 不返回已删除消息；已撤回消息统一按文本返回“消息已撤回”，不返回原内容或媒体地址
- **权限校验**: 历史会话必须早于当前会话，且 `userId`、`doctorId` 必须与当前会话完全一致
- **交互约束**: 历史消息仅供查看，不连接实时消息，也不支持发送、撤回或标记当前会话已读

### 4. 获取指定宠物的 AI 问诊报告

- **路径**: `GET /chat/doctor/sessions/:conversationId/pets/:petId/ai-reports`
- **查询参数**: `page`（默认 1）、`pageSize`（默认 20，最大 50）
- **权限校验**: 宠物必须属于该咨询会话的用户

### 5. 获取 AI 问诊报告详情

- **路径**: `GET /chat/doctor/sessions/:conversationId/ai-reports/:reportId`
- **权限校验**: 报告及其宠物必须属于该咨询会话的用户

### 6. 获取指定宠物的健康档案

- **路径**: `GET /chat/doctor/sessions/:conversationId/pets/:petId/appointments`
- **查询参数**: `page`（默认 1）、`pageSize`（默认 20，最大 50）
- **业务定义**: 医生端“健康档案”就是现有健康预约记录，不新增独立档案表
- **数据来源**: `health_appointments`，包含疫苗、驱虫和体检记录

### 7. 获取健康档案详情

- **路径**: `GET /chat/doctor/sessions/:conversationId/appointments/:appointmentId`
- **权限校验**: 预约及其宠物必须属于该咨询会话的用户
- **响应**: 复用健康预约详情，包含状态、日期、时段、医院、医生、`operationContent`、
  `detailContent` 和备注

### 8. 获取指定宠物的护理建议

- **路径**: `GET /chat/doctor/sessions/:conversationId/pets/:petId/care-plan`
- **响应**: 宠物基础信息、`carePlanStatus`、`carePlan`、`carePlanGeneratedAt` 和
  `carePlanError`；护理建议只读，医生端不触发生成或重新生成
- **权限校验**: 宠物必须属于该咨询会话的用户

通用成功响应由服务端统一包装为：

```json
{
  "code": 0,
  "data": {},
  "message": "Success"
}
```

**钱包模块更新记录:**

- ✅ 修复二手商品销售结算的交易类型（从 `freeze` 改为 `income`）
- ✅ 统一审核列表查询逻辑，确保数据一致性
- ✅ 添加完整的业务流程说明和余额变化示例
- ✅ 新增 Community 模块文档，补充独立关注体系与社区公开资料接口
- ✅ 补充 Community 帖子媒体字段与 Admin 审核接口说明，明确图片/视频的返回结构与展示约束
- ✅ 社区发帖视频新增 `videoCover` 字段，明确前端抽帧上传封面图的链路与展示约束
- ✅ `POST /upload/file` 支持视频与客户端缩略图同传，聊天视频与社区视频统一消费持久化后的 `thumbnail` 地址
- ✅ 新增 Moderation 模块文档，补充 UGC 举报、用户屏蔽、Admin 举报处理和处理动作接口
- ✅ 新增好友聊天黑名单接口，明确好友聊天拉黑与 Moderation 内容屏蔽相互独立
- ✅ 新增医生端咨询用户健康档案接口，支持查看宠物、AI 问诊报告、健康概览、护理建议及复用现有预约的健康档案
- ✅ 新增医生端历史咨询列表和只读消息详情，并按账号类型收紧通用消息读取权限

---


### AI 诊断增量评估（2026-09-10）

适用于 `GET /ai-diagnosis-reports/:id` 的中西医诊断结果；现有报告列表及医生端报告接口沿用相同结果 JSON。

- 西医：保留 `westernDiagnosis.diagnosis` / `medications` 等原字段，新增可选 `westernDiagnosis.assessment` 和 `westernDiagnosis.disclaimer`。
- 中医：有评估/声明的新结果为 `{ data: [...原诊断项], assessment?, disclaimer? }`；旧结果可能仍是数组，调用方需同时兼容数组及对象的 `data` 数组。不回填历史记录，不增加数据库列。
- `assessment` 包含 `status`、`emergency`（紧急程度/原因/行动/缺失信息）、`recommended_tests`（项目/目的/优先级/相关表现/条件）、`temporary_care`（护理/避免事项/升级信号）、`warnings`。结构及枚举遵循 [AI 服务文档](https://github.com/hellolukeding/vet-ai/blob/langgraph/docs/DIAGNOSIS_ASSESSMENT_API.md)。
- 后台队列使用 `async_mode=true` 提交 AI 任务，收到 `task_id` 后每 2 秒查询相应的 `/task/{task_id}`，单轮最多 240 次；超时/失败交由原队列重试机制处理。已保存的 pending 任务 ID 在重试时复用。
- 评估早于主诊断完成时，诊断 JSON 暂存 `{ assessment?, disclaimer?, taskId, taskStatus: "pending" }`（中医同时带 `data: []`）。`taskStatus` 表示主诊断状态，与 `assessment.status` 独立；不能因两个 JSON 非空就将报告标为 `COMPLETED`。
- APP 报告详情生成期间每 5 秒刷新，单次页面最多自动刷新 60 次；失败/退出页面停止，仍可手动刷新。主报告已完成且明确存在 pending 评估时也允许刷新；旧报告无 `assessment` 不触发额外轮询。
- 新字段缺失、null 或空对象时不显示评估卡片，不解释为“没有风险”；部分模块缺失仅隐藏该模块。`pending` 检查项目不作正式建议展示，`unavailable` 明确提示不可用。检查按 urgent → recommended → conditional 排序。
- 中西医分别展示各自评估；任一侧急诊/尽快就医提示置于报告顶部，不等待主诊断完成。保留 `warnings`、接口 `disclaimer` 和原 APP 风险提示，临时处置不得当作治疗方案。

---

### AI 问诊报告 `symptoms` 字段恢复为完整拼接描述（2026-09-11）

- `POST /ai-diagnosis-reports` 的请求体不变：`symptoms` 仍传用户填写的病情主诉原文。
- 服务端入库与返回的 `symptoms` 恢复为完整拼接描述（宠物信息、疫苗/驱虫、生理指标、自查症状、症状描述），与传入 AI 队列的诊断上下文完全一致；列表接口 `GET /ai-diagnosis-reports`、详情接口 `GET /ai-diagnosis-reports/:id` 及医生端 AI 报告接口返回的 `symptoms` 均为该完整描述。
- 客户端与管理端的症状卡片直接展示该字段，文案统一为「症状描述」，不再按「仅病情主诉」处理；自查表快照、基础信息、诊断图片仍各自独立返回，历史记录不回填。


### 微信支付回调原始报文要求

`POST /payment/callback/wechat` 使用原始 UTF-8 请求体进行签名验证，服务启动须开启 `rawBody: true`。验签不得重新序列化 JSON。处理成功直接返回 HTTP 200 和 `{ "code": "SUCCESS", "message": "成功" }`；处理失败返回 HTTP 500 和 `{ "code": "FAIL", "message": "处理失败" }`，均不经过业务响应包装。
