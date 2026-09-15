# Admin 公开隐私政策页面实现计划

> **面向 AI 代理的工作者：** 在当前会话内联执行；步骤使用复选框（`- [ ]`）跟踪进度。仓库规则禁止未经用户明确授权自行提交，因此本计划不包含 commit。

**目标：** 在 Admin 部署域名提供无需登录的 `/#/privacy-policy` 页面，并展示后台维护的隐私协议。

**架构：** 将公共页面注册为不使用后台 `Layout` 的常量路由，并加入未登录白名单。页面通过一个可独立测试的状态加载函数调用现有系统文章 API，再根据成功、空内容或失败状态渲染对应界面。

**技术栈：** Vue 3、Vue Router、TypeScript、Element Plus、现有 Axios 封装、esno

---

## 文件结构

- 创建 `admin/src/views/Public/PrivacyPolicy/privacy-policy-state.ts`：封装文章请求和页面状态转换。
- 创建 `admin/src/views/Public/PrivacyPolicy/privacy-policy-state.spec.ts`：覆盖成功、空内容和异常状态。
- 创建 `admin/src/views/Public/PrivacyPolicy/index.vue`：公开隐私政策页面。
- 修改 `admin/src/router/index.ts`：注册 `/privacy-policy` 常量路由。
- 修改 `admin/src/constants/index.ts`：允许未登录访问并在路由重置时保留页面。

### 任务 1：用 TDD 定义数据状态

- [ ] **步骤 1：编写失败测试**

创建测试，断言加载函数把公开 API 响应转换为以下状态：

```typescript
{ status: 'ready', content: '<p>正文</p>', updatedAt: '2026-07-11T00:00:00.000Z' }
{ status: 'empty', content: '', updatedAt: '' }
{ status: 'error', content: '', updatedAt: '' }
```

- [ ] **步骤 2：运行测试并确认因模块缺失而失败**

运行：

```bash
cd admin && pnpm exec esno src/views/Public/PrivacyPolicy/privacy-policy-state.spec.ts
```

预期：退出码非 0，提示无法找到 `privacy-policy-state`。

- [ ] **步骤 3：实现最小状态加载函数**

导出 `loadPrivacyPolicy(fetchArticle)`，捕获请求异常并返回可判别联合类型，不在状态层触发 UI 副作用。

- [ ] **步骤 4：重新运行测试**

运行相同步骤 2 命令，预期退出码为 0，输出三个测试场景均通过。

### 任务 2：实现公共页面和路由

- [ ] **步骤 1：新增公开页面**

页面挂载时调用：

```typescript
loadPrivacyPolicy(() => getSystemArticleByTypeApi(ArticleType.PRIVACY))
```

页面提供加载、正文、空内容、失败与重试状态，正文用 `v-html` 渲染后台富文本。

- [ ] **步骤 2：注册常量路由**

在 `constantRouterMap` 中新增独立路由：

```typescript
{
  path: '/privacy-policy',
  component: () => import('@/views/Public/PrivacyPolicy/index.vue'),
  name: 'PrivacyPolicy',
  meta: { hidden: true, title: '隐私政策', noTagsView: true }
}
```

- [ ] **步骤 3：开放未登录访问**

将 `/privacy-policy` 加入 `NO_REDIRECT_WHITE_LIST`，将 `PrivacyPolicy` 加入 `NO_RESET_WHITE_LIST`。

### 任务 3：验证与浏览器检查

- [ ] **步骤 1：运行定向状态测试**

```bash
cd admin && pnpm exec esno src/views/Public/PrivacyPolicy/privacy-policy-state.spec.ts
```

- [ ] **步骤 2：运行类型检查和生产构建**

```bash
cd admin && pnpm ts:check
cd admin && pnpm build:pro
```

- [ ] **步骤 3：启动本地 Admin**

```bash
cd admin && pnpm dev --host 127.0.0.1
```

- [ ] **步骤 4：检查桌面和手机视口**

打开 `http://127.0.0.1:<port>/#/privacy-policy`，确认无需登录、页面没有后台 Layout、各状态无重叠，并检查浏览器控制台和网络请求。

