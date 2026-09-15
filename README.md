# 谷德E宠 / Pet Hospitals

本仓库包含 Flutter 客户端、Vue 管理端和 NestJS 后端。源码来自 `pet-hospitals-new_flutter.zip`，首次入库前进行了静态检查和部分自动化验证。

## 目录

- `flutter_app/`：Android / iOS Flutter 应用。
- `admin/`：Vue 3、TypeScript、Element Plus 管理端。
- `server/`：NestJS、TypeORM、MySQL、Redis 后端。
- `admin/API_DOCUMENT.md`：后端 API 文档。

## 本地开发

后端使用 Node.js 22 与 pnpm。复制 `server/.env.example` 为 `server/.env`，填写自己的测试数据库、Redis 和所需服务配置。数据库自动同步已禁用，启动前请审核并执行适用的数据库迁移；不要直接连接生产数据库试运行迁移。

```sh
cd server
pnpm install --frozen-lockfile
pnpm run build
pnpm run start:dev
```

管理端：

```sh
cd admin
pnpm install --frozen-lockfile
pnpm run ts:check
pnpm run build:pro
pnpm run dev
```

Flutter SDK 需满足 `flutter_app/pubspec.yaml` 中的 Dart SDK 约束。手机端默认 API 指向生产服务，本地验证时显式传入测试地址：

```sh
cd flutter_app
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://YOUR_TEST_SERVER:3000
```

真实 `.env`、支付私钥、云服务凭据、日志及本机 AI 工具配置不会提交。请自行通过部署环境注入凭据。

## 验证

后端默认测试集合中 `src/redis/redis.spec.ts` 需要本地 Redis，且使用 `test_key` 和 `test_list` 测试键；请使用隔离测试实例。没有 Redis 时可只运行其余用例，但不能将此解释为完整集成测试通过：

```sh
cd server
pnpm exec jest --runInBand --testPathIgnorePatterns /redis/redis.spec.ts
```

已知功能缺口：`GET /payment/list` 与 `GET /payment/my` 仍返回未实现错误。源码入库不等于可直接生产部署。

## 首次入库检查记录（2026-09-15）

- 修复停用医生仍可通过 JWT 鉴权的问题，补充回归测试。
- 修复微信回调原始请求体读取、验签报文和回执格式，补充 HTTP 与服务层测试。
- 补齐后端 mapped-types，以及管理端图标、ESLint 配置使用的直接依赖，更新 pnpm 锁文件。
- 将优惠券测试时间固定在测试数据有效期内，修正过时的测试替身和构造参数。
- 恢复测试文件的 Git 跟踪；排除真实服务配置、日志和本机工具设置。
- 后端 `pnpm run build` 通过；不含 Redis 实例测试的 49 组、316 个用例通过。
- 管理端 `pnpm run ts:check`、`pnpm run build:pro` 通过。构建包含 mockjs eval 等依赖警告；构建产物不提交。
- 未验证：Flutter analyze/test 与 iOS/Android 打包、真实 Redis/MySQL 联调、真实支付回调和生产部署。

这些结果是本次检查范围内的证据，不是完整业务验收或安全审计结论。
