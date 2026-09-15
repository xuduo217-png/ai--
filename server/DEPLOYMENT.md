# 宝塔面板部署指南

## 📋 部署前准备

### 1. 服务器要求
- **操作系统**: CentOS 7+ / Ubuntu 18.04+
- **内存**: 最低 2GB（推荐 4GB）
- **磁盘**: 最低 20GB（推荐 50GB+）
- **网络**: 公网 IP，开放 80、443 端口

### 2. 需要安装的软件（通过宝塔面板安装）
- **Nginx** 1.20+ （Web 服务器）
- **MySQL** 5.7+ 或 8.0+ （数据库）
- **Node.js** 18.x+ （运行环境）
- **PM2** （进程管理，Node.js 管理器会自动安装）
- **Redis** （可选，用于队列和缓存）

---

## 🚀 部署步骤

### 步骤 1：安装宝塔面板

如果服务器尚未安装宝塔面板：

```bash
# CentOS 安装命令
yum install -y wget && wget -O install.sh https://download.bt.cn/install/install_6.0.sh && sh install.sh

# Ubuntu 安装命令
wget -O install.sh https://download.bt.cn/install/install-ubuntu_6.0.sh && sudo bash install.sh
```

安装完成后，登录宝塔面板（默认端口 8888）。

---

### 步骤 2：安装运行环境

在宝塔面板 **"软件商店"** 中安装以下软件：

1. **Nginx** 1.22+ （点击安装，选择编译安装或极速安装）
2. **MySQL** 8.0 （设置 root 密码并记住）
3. **Node.js** 18.x 或 20.x （推荐 20.x）
4. **Redis** 7.x （可选，如果使用队列和缓存）
5. **PM2** （在 Node.js 管理器中会自动安装）

---

### 步骤 3：创建数据库

1. 进入宝塔面板 **"数据库"**
2. 点击 **"添加数据库"**
3. 填写信息：
   - **数据库名**: `pet_hospitals`
   - **用户名**: 自动生成或自定义
   - **密码**: 自动生成或自定义（**请记住密码！**）
   - **访问权限**: 本地服务器
4. 记录数据库信息（用户名、密码），稍后配置使用

---

### 步骤 4：创建网站

1. 进入宝塔面板 **"网站"** -> **"添加站点"**
2. 填写信息：
   - **域名**: `gudeapi.zuoyongyoubao.com`
   - **根目录**: `/www/wwwroot/gudeapi.zuoyongyoubao.com`
   - **FTP**: 不创建
   - **数据库**: 不创建（已在步骤 3 创建）
   - **PHP版本**: 纯静态（不使用 PHP）

---

### 步骤 5：上传项目文件

有两种方式上传代码：

#### 方式 A：使用 Git（推荐）

1. 在宝塔面板 **"文件"** 中，进入 `/www/wwwroot/`
2. 右键点击，选择 **"Git Clone"**
3. 输入仓库地址，克隆到 `gudeapi.zuoyongyoubao.com` 目录

#### 方式 B：手动上传

1. 本地进入项目 `server/` 目录
2. 删除不需要的文件：
   ```bash
   # 删除以下文件和目录以减小上传体积
   rm -rf node_modules
   rm -rf .git
   rm -rf dist
   rm -rf coverage
   rm -rf logs/*
   ```
3. 压缩剩余文件为 `server.zip`
4. 在宝塔面板 **"文件"** 中，进入 `/www/wwwroot/gudeapi.zuoyongyoubao.com/`
5. 删除默认的 `index.html` 和 `404.html`
6. 上传 `server.zip` 并解压
7. 将解压后的文件移动到根目录

---

### 步骤 6：配置环境变量

1. 在宝塔面板 **"文件"** 中，进入 `/www/wwwroot/gudeapi.zuoyongyoubao.com/`
2. 复制 `.env.example` 为 `.env`：
   ```bash
   cp .env.example .env
   ```
3. 编辑 `.env` 文件，修改以下配置：

   ```bash
   # 环境配置
   NODE_ENV=production

   # 数据库配置（使用步骤 3 创建的数据库信息）
   DB_HOST=localhost
   DB_PORT=3306
   DB_USERNAME=your_database_username
   DB_PASSWORD=your_database_password
   DB_DATABASE=pet_hospitals

   # JWT 配置（使用强随机字符串！）
   JWT_SECRET=your_production_jwt_secret_please_change_this

   # 文件上传目录
   UPLOAD_DEST=/www/wwwroot/gudeapi.zuoyongyoubao.com/uploads

   # 腾讯云短信配置（如果需要）
   SMS_SECRET_ID=your_tencent_secret_id
   SMS_SECRET_KEY=your_tencent_secret_key
   SMS_APP_ID=your_tencent_app_id
   SMS_TEMPLATE_ID=your_sms_template_id

   # 支付配置（如果需要）
   ALIPAY_APP_ID=your_alipay_app_id
   ALIPAY_PRIVATE_KEY=your_alipay_private_key
   ALIPAY_PUBLIC_KEY=your_alipay_public_key
   ```

---

### 步骤 7：安装依赖并构建

1. 在宝塔面板 **"终端"**（或 SSH 连接服务器）
2. 进入项目目录：
   ```bash
   cd /www/wwwroot/gudeapi.zuoyongyoubao.com
   ```
3. 安装依赖：
   ```bash
   npm install
   ```
4. 构建项目：
   ```bash
   npm run build
   ```
5. 创建必要的目录：
   ```bash
   mkdir -p /www/wwwroot/gudeapi.zuoyongyoubao.com/uploads
   mkdir -p /www/wwwroot/gudeapi.zuoyongyoubao.com/logs
   ```

---

### 步骤 8：使用 PM2 启动应用

有两种方式启动：

#### 方式 A：使用宝塔面板 Node.js 管理器

1. 进入宝塔面板 **"软件商店"** -> **"已安装"** -> **"Node.js 管理器"**
2. 点击 **"设置"**
3. 点击 **"添加项目"**
4. 填写信息：
   - **项目目录**: `/www/wwwroot/gudeapi.zuoyongyoubao.com`
   - **启动文件**: `dist/src/main.js`
   - **项目名称**: `pet-hospitals-api`
   - **端口**: `3000`
   - **运行模式**: `cluster`
5. 点击 **"提交"**

#### 方式 B：使用命令行

1. 在终端中执行：
   ```bash
   cd /www/wwwroot/gudeapi.zuoyongyoubao.com

   # 启动应用
   pm2 start ecosystem.config.js --env production

   # 查看运行状态
   pm2 status

   # 查看日志
   pm2 logs pet-hospitals-api

   # 设置开机自启
   pm2 startup
   pm2 save
   ```

---

### 步骤 9：配置 Nginx 反向代理

1. 进入宝塔面板 **"网站"** -> 找到 `gudeapi.zuoyongyoubao.com` -> 点击 **"设置"**
2. 点击 **"配置文件"**
3. 复制 [nginx.conf](./nginx.conf) 中的配置，**替换整个配置文件**
4. 点击 **"保存"**
5. 执行 `nginx -t`，确认配置合法后重新加载 Nginx

**重要**：配置文件中会自动填充 SSL 证书路径，无需手动修改。

配置包含 Apple AASA 精确路径 `/.well-known/apple-app-site-association`。该路径在 HTTPS 下必须直接返回 `200` 和 `application/json`，不能代理到 NestJS，也不能再次重定向。

---

### 步骤 10：配置 SSL 证书（HTTPS）

1. 进入宝塔面板 **"网站"** -> 找到 `gudeapi.zuoyongyoubao.com` -> 点击 **"设置"**
2. 点击 **"SSL"**
3. 选择 **"Let's Encrypt"** 免费证书
4. 填写邮箱，点击 **"申请"**
5. 等待证书申请成功
6. 开启 **"强制 HTTPS"**

**注意**：域名 `gudeapi.zuoyongyoubao.com` 需要已正确解析到服务器 IP。

在支付宝开放平台为 iOS 应用登记以下信息：

- Bundle ID：`com.gude.cwyy`
- Universal Link：`https://gudeapi.zuoyongyoubao.com/alipay/`
- URL Scheme：`ap2021006115617866`

Universal Link 必须与 Flutter iOS 工程中的 Associated Domains 及支付调用参数完全一致。

---

### 步骤 11：配置防火墙

1. 进入宝塔面板 **"安全"**
2. 确保以下端口已开放：
   - `80`（HTTP）
   - `443`（HTTPS）
   - `22`（SSH）
   - `8888`（宝塔面板）
3. 关闭其他不必要的端口

---

### 步骤 12：初始化数据库（可选）

如果需要填充种子数据：

```bash
cd /www/wwwroot/gudeapi.zuoyongyoubao.com
npm run seed
```

---

## ✅ 验证部署

### 1. 检查 PM2 运行状态

```bash
pm2 status
```

应显示 `pet-hospitals-api` 为 `online` 状态。

### 2. 访问 API 接口

在浏览器中访问：

- **API 文档**: `https://gudeapi.zuoyongyoubao.com/api-docs`
- **健康检查**: `https://gudeapi.zuoyongyoubao.com`

### 3. 测试接口

使用 Postman 或 curl 测试接口：

```bash
curl https://gudeapi.zuoyongyoubao.com/auth/login
```

### 4. 验证 Apple AASA

```bash
curl -i https://gudeapi.zuoyongyoubao.com/.well-known/apple-app-site-association
```

响应应为 `HTTP/2 200`（或 `HTTP/1.1 200`）、`Content-Type: application/json`，且不能包含 `Location` 响应头。JSON 中应包含 `RK2294UDR8.com.gude.cwyy` 和 `/alipay/*`。

---

## 🔄 更新部署

当代码有更新时：

1. **拉取最新代码**（如果使用 Git）：
   ```bash
   cd /www/wwwroot/gudeapi.zuoyongyoubao.com
   git pull
   ```

   或 **重新上传文件**（如果手动上传）

2. **安装新依赖**（如果 package.json 有变化）：
   ```bash
   npm install
   ```

3. **重新构建**：
   ```bash
   npm run build
   ```

4. **重启应用**：
   ```bash
   pm2 restart pet-hospitals-api
   ```

---

## 📊 监控和日志

### 查看 PM2 日志

```bash
# 实时查看日志
pm2 logs pet-hospitals-api

# 查看错误日志
pm2 logs pet-hospitals-api --err

# 清空日志
pm2 flush
```

### 查看 Nginx 日志

在宝塔面板 **"文件"** 中：
- **访问日志**: `/www/wwwroot/gudeapi.zuoyongyoubao.com/logs/access.log`
- **错误日志**: `/www/wwwroot/gudeapi.zuoyongyoubao.com/logs/error.log`

---

## 🔧 常见问题

### 1. 端口 3000 被占用

```bash
# 查看占用进程
lsof -i:3000

# 杀死进程
kill -9 [PID]
```

### 2. 数据库连接失败

- 检查 `.env` 中的数据库配置是否正确
- 确认 MySQL 服务已启动
- 检查数据库用户权限

### 3. 文件上传失败

- 检查 `uploads` 目录是否有写入权限：
  ```bash
  chmod 755 /www/wwwroot/gudeapi.zuoyongyoubao.com/uploads
  ```
- 检查 Nginx `client_max_body_size` 配置

### 4. WebSocket 连接失败

- 检查 Nginx 配置中是否正确设置了 WebSocket 代理
- 确认防火墙允许 WebSocket 连接

---

## 🔒 安全建议

1. **定期更新**: 保持宝塔面板、Nginx、MySQL、Node.js 为最新版本
2. **强密码**: 使用强密码作为数据库密码和 JWT_SECRET
3. **备份策略**:
   - 每日自动备份数据库
   - 每周备份上传文件
   - 备份保留至少 30 天
4. **限制访问**:
   - 生产环境关闭 Swagger 文档或限制 IP 访问
   - 使用防火墙限制来源 IP
5. **SSL 证书**: 启用 HTTPS 并配置自动续期
6. **监控告警**: 配置宝塔面板的监控和告警功能

---

## 📞 技术支持

如遇到问题，请检查：
1. PM2 日志：`pm2 logs pet-hospitals-api`
2. Nginx 错误日志：`/www/wwwroot/gudeapi.zuoyongyoubao.com/logs/error.log`
3. 应用错误日志：`/www/wwwroot/gudeapi.zuoyongyoubao.com/logs/pm2-error.log`

---

**部署完成后，请删除本文件中的敏感信息！**
