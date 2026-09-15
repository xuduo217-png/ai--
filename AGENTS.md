## 项目结构与技术栈

- `flutter_app/` 是 Flutter/Dart 客户端，包含 iOS 与 Android 原生工程目录。
- `admin/` 是 Vue 3 管理端。
- `server/` 是后端服务。
- 涉及 `flutter_app/`、iOS、Android、移动端打包或发布的任务，必须按 Flutter 项目处理；原生 `ios/`、`android/` 目录的存在不代表项目使用 React Native 或 Expo。
- 不得对本项目的 Flutter 任务使用 `react-native-skills`。只有仓库实际引入 React Native/Expo，且当前任务明确涉及对应代码时，才可使用该 Skill。
- Flutter 应用版本的默认配置源是 `flutter_app/pubspec.yaml` 中的 `version: <外部版本号>+<内部版本号>`。iOS 中分别映射为 `CFBundleShortVersionString` 和 `CFBundleVersion`；命令行显式传入的 `--build-name`、`--build-number` 可以覆盖默认值。

## server 端代码风格

###  修改接口后，需要更新后端 API 文档

- 后端 API 文档位置：admin/API_DOCUMENT.md
- 因为 admin 端调用的 api 是从后端服务器获取的，所以需要更新admin端 API 文档


## admin 端代码风格

### 接口文档位置

- 后端 API 文档位置：admin/API_DOCUMENT.md

- api 调用时，使用 axios 库
- 所有 api 调用都要在 try-catch 中处理异常
- 所有 api 调用都要在请求头中添加 token
- api 调用时，使用 async/await 语法
- api 封装到 src/api-new 目录下，每个 api 对应一个文件
- api 需要进行导出，导出的文件在 src/api-new/index.ts
- 每个 api 文件导出一个函数，函数名就是 api 调用的方法名
- 每个 api 函数都要接收一个参数，参数是一个对象，对象的属性就是 api 调用的参数
- 每个 api 函数都要返回一个 Promise，Promise 的 resolve 是 api 调用的返回值，Promise 的 reject 是 api 调用的异常

### Element Plus 组件导入规范

**重要说明**：Element Plus 组件需要**显式导入**才能使用。项目中部分组件已全局注册（如 ElMessage、ElTag 等），但大部分组件需要手动导入。

#### 基本规则
1. **所有 Element Plus 组件都必须显式导入**（除非已全局注册）
2. **从 `element-plus` 包中导入组件**，而不是使用全局变量
3. **在 `<script setup>` 中导入后即可直接使用**，无需额外注册

#### 导入语法
```typescript
import { ElComponent } from 'element-plus'
```

#### 常用组件导入示例

**基础组件**：
```typescript
import { ElButton } from 'element-plus'
import { ElTag } from 'element-plus'
import { ElIcon } from 'element-plus'
import { ElCard } from 'element-plus'
```

**数据展示**：
```typescript
import { ElTable } from 'element-plus'
import { ElTableColumn } from 'element-plus'
import { ElDescriptions } from 'element-plus'
import { ElDescriptionsItem } from 'element-plus'
import { ElCollapse } from 'element-plus'
import { ElCollapseItem } from 'element-plus'
```

**布局容器**：
```typescript
import { ElTabs } from 'element-plus'
import { ElTabPane } from 'element-plus'
import { ElDialog } from 'element-plus'
import { ElDrawer } from 'element-plus'
```

**反馈组件**：
```typescript
import { ElMessage } from 'element-plus'
import { ElMessageBox } from 'element-plus'
import { ElNotification } from 'element-plus'
```

#### 完整示例

```vue
<script setup lang="ts">
import { ref } from 'vue'
// 导入需要的 Element Plus 组件
import {
  ElTabs,
  ElTabPane,
  ElTable,
  ElTableColumn,
  ElCard,
  ElTag,
  ElButton,
  ElMessage
} from 'element-plus'

// 导入图标
import { InfoFilled, Loading } from '@element-plus/icons-vue'

const activeTab = ref('western')
</script>

<template>
  <el-card>
    <el-tabs v-model="activeTab">
      <el-tab-pane label="西医诊断" name="western">
        <!-- 内容 -->
      </el-tab-pane>
    </el-tabs>
  </el-card>
</template>
```

#### 注意事项
1. **一次性导入多个组件**：使用解构导入可以提高可读性
2. **图标导入**：图标从 `@element-plus/icons-vue` 导入，而不是 `element-plus`
3. **类型定义**：某些组件可能需要导入类型，如 `import type { FormInstance } from 'element-plus'`
4. **全局注册的组件**：项目可能已全局注册部分常用组件（如 ElMessage），使用时无需导入，具体查看项目配置

#### 如何判断组件是否需要导入
如果在模板中使用组件时报错 "Unknown custom element" 或组件不显示，通常需要手动导入该组件。

```ts
/**
 * 商品管理 API
 */

import request from '@/axios'
import type {
  Product,
  ProductQueryParams,
  ProductCreateParams,
  ProductUpdateParams,
  ProductSku,
  PaginatedResponse
} from './types'

// API 基础路径（从环境变量获取）
const BASE_URL = import.meta.env.VITE_SERVER_API_BASE_URL || '/server-api'

/**
 * 获取商品列表（支持分页和筛选）
 */
export const getProductListApi = (params: ProductQueryParams) => {
  return request.get<PaginatedResponse<Product>>({
    url: `${BASE_URL}/shop/products`,
    params
  })
}

/**
 * 获取商品详情
 */
export const getProductDetailApi = (id: number) => {
  return request.get<Product>({
    url: `${BASE_URL}/shop/products/${id}`
  })
}

/**
 * 创建商品
 */
export const createProductApi = (data: ProductCreateParams) => {
  return request.post<Product>({
    url: `${BASE_URL}/shop/products`,
    data
  })
}

/**
 * 更新商品
 */
export const updateProductApi = (id: number, data: ProductUpdateParams) => {
  return request.put<Product>({
    url: `${BASE_URL}/shop/products/${id}`,
    data
  })
}

/**
 * 删除商品
 */
export const deleteProductApi = (id: number) => {
  return request.delete({
    url: `${BASE_URL}/shop/products/${id}`
  })
}
```

## 图片上传组件使用规范

### 组件位置
`admin/src/components/ImageUpload/`

### 重要说明
**项目中所有图片上传必须统一使用 ImageUpload 组件**，以确保用户体验一致性和代码可维护性。

### 基础用法

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { ImageUpload } from '@/components/ImageUpload'

const logoUrl = ref('')
</script>

<template>
  <ImageUpload v-model="logoUrl" />
</template>
```

### 常用配置

#### 方形图片（1:1，适用于 Logo、头像）
```vue
<ImageUpload
  v-model="logo"
  :aspect-ratio="1"
  :crop-box-width="200"
  :crop-box-height="200"
  category="logo"
  dialog-title="上传 Logo"
/>
```

#### 横向图片（16:9，适用于封面、横幅）
```vue
<ImageUpload
  v-model="banner"
  :aspect-ratio="16 / 9"
  :crop-box-width="640"
  :crop-box-height="360"
  category="banner"
  dialog-title="上传封面图片"
/>
```

#### 圆形头像
```vue
<ImageUpload
  v-model="avatar"
  :circle="true"
  :preview-width="120"
  :preview-height="120"
  :aspect-ratio="1"
  :crop-box-width="200"
  :crop-box-height="200"
  category="avatar"
  dialog-title="上传头像"
/>
```

### Props 说明

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| v-model | string | '' | 绑定的图片 URL（双向绑定） |
| aspectRatio | number | 1 | 裁剪比例（1=1:1, 16/9=16:9） |
| cropBoxWidth | number | 200 | 裁剪框宽度（像素） |
| cropBoxHeight | number | 200 | 裁剪框高度（像素） |
| circle | boolean | false | 是否圆形预览 |
| category | string | - | 文件分类（便于后端管理） |
| maxSize | number | 5 | 最大文件大小（MB） |
| dialogTitle | string | '上传图片' | 对话框标题 |
| previewWidth | number | 148 | 预览区宽度（像素） |
| previewHeight | number | 148 | 预览区高度（像素） |
| placeholder | string | '点击上传图片' | 占位文本 |
| disabled | boolean | false | 是否禁用 |

### Events 说明

| 事件 | 参数 | 说明 |
|------|------|------|
| @success | response | 上传成功时触发，返回服务器响应 |
| @error | error | 上传失败时触发，返回错误信息 |
| @progress | percent | 上传进度变化时触发，返回进度百分比 |
| @dialog-open | - | 裁剪对话框打开时触发 |
| @dialog-close | - | 裁剪对话框关闭时触发 |

### 在 CRUD Schema 中使用

```tsx
// 获取服务器基础地址（用于拼接图片 URL）
const SERVER_BASE_URL = import.meta.env.VITE_API_BASE_PATH || 'http://localhost:3000'

{
  field: 'logo',
  label: 'Logo 图片',
  search: { hidden: true },
  form: {
    component: 'ImageUpload',
    componentProps: {
      placeholder: '点击上传医院 Logo',
      aspectRatio: 1,
      cropBoxWidth: 200,
      cropBoxHeight: 200,
      category: 'hospital-logo',
      circle: false,
      previewWidth: 100,
      previewHeight: 100
    }
  },
  table: {
    show: true,
    width: 100,
    slots: {
      default: (data: any) => {
        return data.row.logo ? (
          <img
            src={data.row.logo.startsWith('http') ? data.row.logo : `${SERVER_BASE_URL}${data.row.logo}`}
            style={{ width: '50px', height: '50px', objectFit: 'cover', borderRadius: '4px' }}
            alt="Logo"
          />
        ) : (
          <span>-</span>
        )
      }
    }
  }
}
```

## CRUD Schema 表格列渲染规范

### 重要规则

**规则 1：隐藏表格列**
- **在 CRUD Schema 中隐藏表格列时，必须使用 `table: { hidden: true }`**
- **不能使用 `table: { show: false }`**（不会生效）

**规则 2：自定义表格列渲染**
- **在 CRUD Schema 中定义表格列的自定义渲染时，必须使用 `table.slots.default`，不能使用 `tableRender`**

### 为什么使用 hidden 而不是 show
- `useCrudSchemas` hook 识别的隐藏属性是 `hidden: true`
- 使用 `show: false` 不会生效，列仍会显示在表格中

### 为什么使用 slots 而不是 tableRender
- `table.slots.default` 是项目框架 `useCrudSchemas` 支持的标准方式
- `tableRender` 不会生效，导致表格中显示原始数据而不是自定义渲染内容

### 正确用法示例

#### 1. 隐藏表格列
```tsx
{
  field: 'mapPicker',
  label: '经纬度快速填充',
  search: { hidden: true },
  form: {
    component: 'Input',
    // ... 表单配置
  },
  table: {
    hidden: true  // ✅ 正确：使用 hidden: true 隐藏列
  }
}
```

#### 2. 图片列（需拼接 URL）
```tsx
// 定义服务器基础地址常量
const SERVER_BASE_URL = import.meta.env.VITE_API_BASE_PATH || 'http://localhost:3000'

{
  field: 'logo',
  label: 'Logo 图片',
  table: {
    show: true,
    width: 100,
    slots: {
      default: (data: any) => {
        return data.row.logo ? (
          <img
            src={data.row.logo.startsWith('http') ? data.row.logo : `${SERVER_BASE_URL}${data.row.logo}`}
            style={{ width: '50px', height: '50px', objectFit: 'cover', borderRadius: '4px' }}
            alt="Logo"
          />
        ) : (
          <span>-</span>
        )
      }
    }
  }
}
```

#### 2. 数字格式化列
```tsx
{
  field: 'latitude',
  label: '纬度',
  table: {
    slots: {
      default: (data: any) => {
        // 后端返回的是字符串，需要先转为数字再调用 toFixed
        return data.row.latitude ? Number(data.row.latitude).toFixed(6) : '-'
      }
    }
  }
}
```

#### 3. 状态标签列
```tsx
{
  field: 'isActive',
  label: '状态',
  table: {
    slots: {
      default: (data: any) => {
        return data.row.isActive ? (
          <ElTag type="success">启用</ElTag>
        ) : (
          <ElTag type="danger">禁用</ElTag>
        )
      }
    }
  }
}
```

#### 4. 自定义操作列
```tsx
{
  field: 'action',
  label: '操作',
  table: {
    slots: {
      default: (data: any) => {
        return (
          <>
            <BaseButton type="primary" onClick={() => handleEdit(data.row)}>
              编辑
            </BaseButton>
            <BaseButton type="danger" onClick={() => handleDelete(data.row)}>
              删除
            </BaseButton>
          </>
        )
      }
    }
  }
}
```

### 常见错误

#### ❌ 错误 1：使用 show: false（不会生效）
```tsx
{
  field: 'mapPicker',
  label: '经纬度快速填充',
  search: { hidden: true },
  form: { /* ... */ },
  table: {
    show: false  // ❌ 错误：show: false 不会生效
  }
}
```

#### ✅ 正确：使用 hidden: true
```tsx
{
  field: 'mapPicker',
  label: '经纬度快速填充',
  search: { hidden: true },
  form: { /* ... */ },
  table: {
    hidden: true  // ✅ 正确：使用 hidden: true
  }
}
```

#### ❌ 错误 2：使用 tableRender（不会生效）
```tsx
{
  field: 'logo',
  label: 'Logo',
  table: {
    show: true
  },
  tableRender: (row) => {  // ❌ 这样不会生效
    return <img src={row.logo} />
  }
}
```

#### ✅ 正确 2：使用 table.slots.default
```tsx
{
  field: 'logo',
  label: 'Logo',
  table: {
    show: true,
    slots: {
      default: (data: any) => {  // ✅ 正确的方式
        return <img src={data.row.logo} />
      }
    }
  }
}
```

### 图片 URL 拼接规则
当后端返回的图片路径是相对路径（如 `/uploads/xxx.jpg`）时，需要拼接服务器基础地址：

```tsx
// 在组件顶部定义常量
const SERVER_BASE_URL = import.meta.env.VITE_API_BASE_PATH || 'http://localhost:3000'

// 判断是否为完整 URL
src={data.row.logo.startsWith('http') ? data.row.logo : `${SERVER_BASE_URL}${data.row.logo}`}
```

### 数据类型处理注意事项
1. **经纬度等数字字段**：后端可能返回字符串类型，需要先转换为数字再调用数字方法
   ```tsx
   Number(data.row.latitude).toFixed(6)
   ```

2. **图片路径**：后端返回的可能是相对路径，需要判断并拼接服务器地址

### 使用注意事项

1. **统一使用组件**：所有图片上传功能必须使用 ImageUpload 组件，禁止直接使用 ElUpload 或其他方式
2. **合理设置 category**：设置合适的文件分类参数，便于后端文件管理和统计
3. **选择合适比例**：根据业务场景选择正确的裁剪比例
   - Logo/头像：1:1 (aspectRatio: 1)
   - 封面/横幅：16:9 (aspectRatio: 16/9)
   - 商品图：4:3 (aspectRatio: 4/3)
4. **圆形头像**：头像类图片设置 circle=true 以获得更好的视觉效果
5. **文件大小限制**：默认最大 5MB，如需调整请设置 maxSize 参数
6. **错误处理**：组件已内置错误提示，无需额外处理上传失败情况

### 上传接口说明

- **接口路径**: `POST /upload/image`
- **认证方式**: JWT（自动添加到请求头）
- **参数格式**: multipart/form-data
- **返回格式**:
```typescript
{
  url: string,          // 服务器文件 URL
  filename: string,     // 服务器文件名
  originalName: string, // 原始文件名
  size: number,         // 文件大小（字节）
  id: number           // 文件记录 ID
}
```

## admin 端 Form 组件使用规范

### 重要说明
**Form 组件不支持 v-model**，必须使用 `setValues()` 和 `getFormData()` 方法来管理表单数据。

### 基本用法

```vue
<script setup lang="ts">
import { Form, FormSchema } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import { useValidator } from '@/hooks/web/useValidator'

const { required } = useValidator()

// 表单配置
const formSchema: FormSchema[] = [
  {
    field: 'name',
    label: '名称',
    component: 'Input',
    componentProps: {
      placeholder: '请输入名称'
    },
    formItemProps: {
      rules: [{ required: true, message: '请输入名称', trigger: 'blur' }]
    }
  }
]

// 表单方法
const { formRegister, formMethods } = useForm()
const { setValues, getFormData, getElFormExpose } = formMethods

// 设置表单值（用于编辑）
const setFormValues = (data: Record<string, any>) => {
  setValues(data)
}

// 获取表单值（用于提交）
const getFormValues = async () => {
  const elForm = await getElFormExpose()
  const valid = await elForm?.validate()
  if (valid) {
    const formData = await getFormData()
    return formData
  }
  return null
}

// 提交表单
const handleSubmit = async () => {
  const elForm = await getElFormExpose()
  const valid = await elForm?.validate()
  if (valid) {
    const formData = await getFormData()
    // 处理提交数据
    console.log('表单数据:', formData)
  }
}
</script>

<template>
  <Form :schema="formSchema" @register="formRegister" label-width="100px" />
</template>
```

### 数据管理方式

| 操作 | 方法 | 说明 |
|------|------|------|
| **设置表单值** | `setValues(data)` | 用于填充表单（编辑时）或重置表单 |
| **获取表单值** | `getFormData()` | 用于获取表单数据（提交时） |
| **表单验证** | `getElFormExpose().validate()` | 验证表单规则 |

### 完整示例：带对话框的 CRUD 表单

```vue
<script setup lang="ts">
import { ref, watch, nextTick } from 'vue'
import { Form, FormSchema } from '@/components/Form'
import { useForm } from '@/hooks/web/useForm'
import { ElMessage } from 'element-plus'

// 对话框状态
const dialogVisible = ref(false)
const editingRow = ref<any>(null)

// 表单相关
const { formRegister, formMethods } = useForm()
const { setValues, getFormData, getElFormExpose } = formMethods

// 表单配置
const formSchema = ref<FormSchema[]>([
  {
    field: 'content',
    label: '回复内容',
    component: 'Input',
    componentProps: {
      type: 'textarea',
      rows: 4
    },
    formItemProps: {
      rules: [{ required: true, message: '请输入回复内容', trigger: 'blur' }]
    }
  }
])

/**
 * 打开新增对话框
 */
const handleAdd = () => {
  editingRow.value = null
  dialogVisible.value = true

  // 等待对话框渲染完成后再设置表单值
  nextTick(() => {
    setValues({
      content: '',
      isActive: true
    })
  })
}

/**
 * 打开编辑对话框
 */
const handleEdit = (row: any) => {
  editingRow.value = row
  dialogVisible.value = true

  nextTick(() => {
    setValues({
      content: row.content,
      isActive: row.isActive
    })
  })
}

/**
 * 提交表单
 */
const handleSubmit = async () => {
  try {
    // 表单验证
    const elForm = await getElFormExpose()
    const valid = await elForm?.validate()
    if (!valid) {
      ElMessage.error('请检查表单数据')
      return
    }

    // 获取表单数据
    const formData = await getFormData()
    console.log('提交的数据:', formData)

    // TODO: 调用 API 提交数据
    dialogVisible.value = false
  } catch (error) {
    console.error('提交失败:', error)
    ElMessage.error('操作失败，请稍后重试')
  }
}
</script>

<template>
  <Dialog v-model="dialogVisible" title="表单" width="600px">
    <Form :schema="formSchema" @register="formRegister" label-width="100px" />
    <template #footer>
      <BaseButton type="primary" @click="handleSubmit">保存</BaseButton>
      <BaseButton @click="dialogVisible = false">取消</BaseButton>
    </template>
  </Dialog>
</template>
```

### 注意事项

1. **不支持 v-model**：Form 组件内部维护状态，不需要也不支持 v-model
2. **使用 setValues**：通过 `setValues(data)` 方法设置表单值，而不是修改 `formData.value`
3. **使用 getFormData**：通过 `getFormData()` 方法获取表单值，而不是访问 `formModel`
4. **等待渲染完成**：在对话框中打开表单时，使用 `nextTick` 确保表单完成渲染后再调用 `setValues`
5. **表单验证**：必须先调用 `validate()` 验证通过后才能获取数据
