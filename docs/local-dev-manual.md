# 本地联调手册（含一键启动）

本手册用于快速拉起 `server + admin + rnapp` 三端联调环境。

## 1. 环境准备

### 1.1 Node 与包管理器

- `server`：Node.js `>=18`
- `admin`：Node.js `>=18`，`pnpm >=8.1`
- `rnapp`：Node.js `>=20`

建议统一使用 Node.js `20.x`。

### 1.2 基础依赖

- MySQL（默认端口 `3306`）
- Redis（默认端口 `6379`）
- Android Studio / Xcode（按 RN 平台需要）
- `adb`（Android 真机调试）

## 2. 配置文件

### 2.1 Server

复制并编辑：

```bash
cd server
cp .env.example .env
```

至少确认以下变量：

- `PORT=3000`
- `DB_HOST` / `DB_PORT` / `DB_USERNAME` / `DB_PASSWORD` / `DB_DATABASE`
- `REDIS_HOST` / `REDIS_PORT`
- `JWT_SECRET`

### 2.2 Admin

开发环境默认读取 `admin/.env.base + admin/.env.dev`。

关键项：

- `VITE_API_BASE_PATH=http://localhost:3000`
- `VITE_STATIC_BASE_PATH=`（推荐留空，自动跟随当前访问 origin；只有静态资源域名与 API 域名不同才单独填写）
- `VITE_SERVER_API_BASE_URL=/server-api`
- `VITE_API_PROXY_TARGET=http://127.0.0.1:8000`
- `VITE_SERVER_API_PROXY_TARGET=http://127.0.0.1:3000`

> `VITE_SERVER_API_BASE_URL=/server-api` 与 `/uploads` 会通过 Vite 代理转发到 `VITE_SERVER_API_PROXY_TARGET`；未显式覆盖时默认指向 `http://127.0.0.1:3000`。
> `/api` 与 `/server-api` 的 Vite 代理目标可以分别通过 `VITE_API_PROXY_TARGET`、`VITE_SERVER_API_PROXY_TARGET` 覆盖，避免把 `vite.config.ts` 里的默认本地地址当成固定配置。
> `VITE_STATIC_BASE_PATH` 留空时，admin 会优先使用当前访问地址的 origin 拼接 `/uploads/...`，避免跨设备访问时仍把图片固定指到 `localhost` / `127.0.0.1`。
> `localhost` / `127.0.0.1` 仅适用于**当前开发机本机浏览器**访问；如果 admin 需要从另一台设备访问，请将 `VITE_API_BASE_PATH` 或代理目标改成可被该设备访问的局域网 IP、域名或反向代理地址。

### 2.3 RN App

RN 端现在已经改成**可配置地址方案**，不再要求手改源码里的固定 IP。

开发环境地址优先级：

1. `__RNAPP_API_BASE_URL__` / `__RNAPP_STATIC_BASE_URL__`
2. `REACT_NATIVE_SERVER_URL` / `REACT_NATIVE_STATIC_URL`
3. 从 Metro bundle 的 `SourceCode.scriptURL` 自动推导当前开发机 host
4. 平台默认回退
   - Android 模拟器：`http://10.0.2.2:3000`
   - iOS 模拟器 / 桌面调试：`http://127.0.0.1:3000`

联调建议：

- 真机：优先显式注入 `__RNAPP_API_BASE_URL__` 或 `REACT_NATIVE_SERVER_URL`
- 模拟器：通常可直接依赖平台默认回退
- 若 Metro 已成功连到当前开发机，RN 也会自动复用 Metro host 推导 API 地址

## 3. 安装依赖

```bash
# server
cd server && npm install

# admin
cd ../admin && pnpm install

# rnapp
cd ../rnapp && npm install

# iOS（仅 iOS 需要）
cd ios && pod install
```

## 4. 一键启动（Web 联调）

在仓库根目录执行：

```bash
./dev.sh
```

脚本会自动拉起：

- `server`：`http://localhost:3000`
- `admin`：`http://localhost:4000`

API 文档：

- Swagger：`http://localhost:3000/api-docs`

> 上述 `localhost` 地址同样只表示本机回环地址；跨设备联调时请替换成当前电脑的局域网 IP、域名或已配置的代理地址。

停止服务：

- 在启动终端按 `Ctrl + C`

## 5. RN 真机联调（Android）

推荐使用仓库根目录脚本：

```bash
./adb-dev.sh
```

常用命令：

```bash
./adb-dev.sh setup      # 首次 USB 配置无线 ADB
./adb-dev.sh connect    # 连接设备
./adb-dev.sh logs       # 查看日志
```

应用启动建议直接在 `rnapp` 目录执行：

```bash
cd rnapp
npm start
npm run android
```

## 6. 常见联调顺序

1. 启动 MySQL / Redis
2. 运行 `./dev.sh`（先保证 Web 与 API 可用）
3. 打开 `http://localhost:4000` 验证后台
4. 启动 RN（`cd rnapp && npm start` + `npm run android`）
5. 在 RN 上验证登录、社区、聊天等接口链路

## 7. 常见问题

### 7.1 Admin 页面打不开或接口 404

- 确认 `dev.sh` 是否正常启动 `server` 与 `admin`
- 确认 `admin/.env.dev` 中 `VITE_SERVER_API_BASE_URL=/server-api`
- 确认 `admin/.env.dev` 中 `VITE_SERVER_API_PROXY_TARGET` 指向当前可达的后端地址
- 如需兼容旧 `/api` 入口，确认 `VITE_API_PROXY_TARGET` 也已同步调整

### 7.2 RN 请求超时/连不上后端

- 检查手机与电脑是否同一局域网
- 检查是否已显式注入 `__RNAPP_API_BASE_URL__` / `REACT_NATIVE_SERVER_URL`
- 如未显式注入，检查 Metro 当前连接的 host 是否为当前电脑
- Android 模拟器默认访问 `10.0.2.2:3000`，iOS 模拟器默认访问 `127.0.0.1:3000`
- 检查后端是否监听 `0.0.0.0:3000`
- 不要把 `localhost:3000` 当作真机可访问地址；真机必须使用局域网 IP、域名或可达代理地址

### 7.3 数据库连接失败

- 检查 `server/.env` 的 DB 配置
- 确认数据库已创建（默认 `pet_hospitals`）
- 查看 `server` 控制台报错详情
