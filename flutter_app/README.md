# 谷德E宠 Flutter 客户端

这是 `rnapp` 的 Flutter 重构工程。工程沿用现有服务端接口，并可与原 React Native 应用并行开发。

## 已迁移功能

- 用户和医生手机号密码登录
- 注册验证码发送、校验和倒计时
- 设置密码并在注册成功后自动登录
- 忘记密码及用户/医生身份选择
- Token、用户信息和身份本地持久化
- 启动时恢复会话并通过 `/auth/profile` 校验 Token
- 退出登录和游客入口
- 登录、注册、设置密码和找回密码 UI 按 RN 当前页面结构与尺寸迁移
- 医生工作台：进行中/已结束咨询、收入统计与明细、医生资料
- 医生在线接诊状态切换
- 医生从咨询列表进入聊天，复用 Flutter 现有聊天页面、媒体消息和实时连接

医生端登录后会按账号身份直接进入医生工作台。医生端使用现有接口：

- `GET /chat/sessions`
- `GET /chat/doctor/income-stats`
- `GET /chat/doctor/income-list`
- `GET /doctors/profile`
- `PATCH /doctors/online-status`
- `GET /chat/messages`

## 运行

默认使用线上 API：`https://gudeapi.zuoyongyoubao.com`。

```bash
flutter pub get
flutter run
```

本地联调时通过编译参数覆盖 API 地址：

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

Android 模拟器访问宿主机服务时通常使用 `http://10.0.2.2:3000`。如果本地服务只支持 HTTP，Android/iOS 还需要按开发环境配置明文网络策略。

## 验证

```bash
flutter analyze
flutter test
```

测试不会调用真实短信或线上登录接口。
