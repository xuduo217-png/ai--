# 富文本图片处理说明

## 问题背景

在使用富文本编辑器时，可能会遇到图片无法显示的问题：

1. **旧数据问题**：如果数据库中存储的是相对路径（如 `/uploads/xxx.jpg`），直接显示富文本会导致图片无法加载
2. **编辑回显问题**：编辑已有内容时，相对路径的图片无法正常显示

## 解决方案

使用 `processHtmlImages()` 工具函数处理富文本内容，自动将相对路径转换为完整 URL。

### 使用方法

#### 1. 在显示富文本内容时使用

```vue
<script setup lang="ts">
import { processHtmlImages } from '@/utils/image'
import { ref, computed } from 'vue'

// 从后端获取的富文本内容（可能包含相对路径）
const content = ref('<p>文章内容</p><img src="/uploads/2024/image.jpg" />')

// 处理后的内容（所有图片路径都是完整 URL）
const processedContent = computed(() => {
  return processHtmlImages(content.value)
})
</script>

<template>
  <!-- 显示处理后的内容 -->
  <div v-html="processedContent" class="article-content"></div>
</template>
```

#### 2. 在编辑器初始化时使用

```vue
<script setup lang="ts">
import { ref, watch } from 'vue'
import { processHtmlImages } from '@/utils/image'

const props = defineProps<{
  modelValue: string
}>()

const emit = defineEmits(['update:modelValue'])

// 编辑器内容
const editorContent = ref('')

// 监听外部数据变化，处理图片路径后回显到编辑器
watch(
  () => props.modelValue,
  (newVal) => {
    // 将相对路径转换为完整 URL，确保编辑器中图片正常显示
    editorContent.value = processHtmlImages(newVal)
  },
  { immediate: true }
)
</script>

<template>
  <Editor v-model="editorContent" />
</template>
```

#### 3. 在提交前清理完整 URL（可选）

如果希望在提交时将完整 URL 转回相对路径（节省数据库空间），可以使用反向处理：

```typescript
import { getBaseURL } from '@/utils/image'

/**
 * 将完整 URL 转换为相对路径（用于提交数据前）
 */
const cleanHtmlImages = (html: string): string => {
  if (!html) return ''

  const baseURL = getBaseURL()
  if (!baseURL) return html

  return html.replace(/<img([^>]*)\s+src=(["']?)([^"'\s>]+)\2/gi, (_match, attrs, quote, src) => {
    // 如果是完整 URL 且指向本服务器，转换为相对路径
    if (src.startsWith(baseURL)) {
      const relativePath = src.replace(new RegExp(`^${baseURL}`), '')
      return `<img${attrs} src=${quote || '"'}${relativePath}${quote || '"'}`
    }
    // 其他 URL（如外部图片）保持不变
    return `<img${attrs} src=${quote || '"'}${src}${quote || '"'}`
  })
}

// 提交前处理
const handleSubmit = async () => {
  const cleanedContent = cleanHtmlImages(editorContent.value)
  await updateArticleApi({ content: cleanedContent })
}
```

### 在 CRUD Schema 中使用

如果使用 `useCrudSchemas` 和 Form 组件，可以通过 `componentProps` 传入处理函数：

```typescript
const crudSchemas = [
  {
    field: 'content',
    label: '文章内容',
    form: {
      component: 'Editor',
      componentProps: {
        // 在编辑器中处理图片路径
        onCreated: (editor: IDomEditor) => {
          // 获取当前内容
          const html = editor.getHtml()
          // 处理图片路径
          const processed = processHtmlImages(html)
          // 设置回编辑器
          editor.setHtml(processed)
        }
      }
    }
  }
]
```

### 处理逻辑说明

`processHtmlImages()` 函数会：

1. **查找所有 `<img>` 标签**：使用正则表达式匹配 HTML 中的图片标签
2. **提取 `src` 属性**：获取图片 URL，支持单引号、双引号、无引号格式
3. **智能判断**：
   - 如果是相对路径（如 `/uploads/xxx.jpg`），自动拼接服务器地址
   - 如果是完整 URL（如 `http://example.com/xxx.jpg`），保持不变
   - 如果是空值，返回空字符串

### 示例对比

#### 输入（包含相对路径）

```html
<p>这是一篇文章</p>
<img src="/uploads/2024/01/image1.jpg" />
<img src="/uploads/2024/01/image2.jpg" />
```

#### 输出（完整 URL）

```html
<p>这是一篇文章</p>
<img src="https://api.example.com/uploads/2024/01/image1.jpg" />
<img src="https://api.example.com/uploads/2024/01/image2.jpg" />
```

### 注意事项

1. **安全性**：此函数仅处理图片 URL，不涉及 HTML 清理。如果用户输入的富文本内容不可信，建议配合 DOMPurify 等 XSS 防护库使用。

2. **性能**：此函数使用正则表达式替换，性能较好。但如果富文本内容非常大（如超过 1MB），建议仅在必要时调用。

3. **向后兼容**：此函数可以正确处理旧数据（相对路径）和新数据（完整 URL），无需修改已有数据。

4. **环境变量优先级**：完整地址优先读取 `VITE_STATIC_BASE_PATH`；若 `VITE_SERVER_API_BASE_URL` 使用相对路径（如 `/server-api`），未配置时会优先回退到当前访问 origin；其余场景再回退到 `VITE_API_BASE_PATH`。开发期不建议把示例值固定写成 `localhost`。

### 完整示例：文章编辑页面

```vue
<script setup lang="ts">
import { ref, watch, computed } from 'vue'
import { Editor } from '@/components/Editor'
import { processHtmlImages } from '@/utils/image'

interface Article {
  id: number
  title: string
  content: string
}

const props = defineProps<{
  currentRow: Article | null
}>()

// 编辑器内容
const editorContent = ref('')

// 监听外部数据变化
watch(
  () => props.currentRow,
  (row) => {
    if (row?.content) {
      // 处理图片路径，确保编辑器中图片正常显示
      editorContent.value = processHtmlImages(row.content)
    }
  },
  { immediate: true }
)

// 提交数据
const handleSubmit = async () => {
  // 可以选择：直接保存完整 URL（推荐）
  const submitData = {
    ...props.currentRow,
    content: editorContent.value
  }

  // 或者：转回相对路径保存（节省存储空间）
  // const submitData = {
  //   ...props.currentRow,
  //   content: cleanHtmlImages(editorContent.value)
  // }

  await updateArticleApi(submitData)
}
</script>

<template>
  <Editor v-model="editorContent" height="500px" />
  <el-button @click="handleSubmit">保存</el-button>
</template>
```

## 相关文档

- [图片 URL 处理规范](./CLAUDE.md#图片-url-处理)
- [环境配置说明](./CLAUDE.md#环境设置)
- [Editor 组件文档](../src/components/Editor/README.md)
