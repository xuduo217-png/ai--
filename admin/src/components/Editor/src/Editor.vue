<script setup lang="ts">
import { onBeforeUnmount, computed, PropType, unref, nextTick, ref, watch, shallowRef } from 'vue'
import { Editor, Toolbar } from '@wangeditor/editor-for-vue'
import { IDomEditor, IEditorConfig, i18nChangeLanguage } from '@wangeditor/editor'
import { propTypes } from '@/utils/propTypes'
import { isNumber } from '@/utils/is'
import { ElMessage } from 'element-plus'
import { useLocaleStore } from '@/store/modules/locale'
import { uploadImageApi, uploadVideoApi } from '@/api-new/upload'
import { getUploadErrorMessage, getUploadMediaValidationError } from '@/utils/upload'

const localeStore = useLocaleStore()

const currentLocale = computed(() => localeStore.getCurrentLocale)

i18nChangeLanguage(unref(currentLocale).lang)

const props = defineProps({
  editorId: propTypes.string.def('wangeEditor-1'),
  height: propTypes.oneOfType([Number, String]).def('500px'),
  editorConfig: {
    type: Object as PropType<IEditorConfig>,
    default: () => undefined
  },
  modelValue: propTypes.string.def('')
})

const emit = defineEmits(['change', 'update:modelValue'])

// 编辑器实例，必须用 shallowRef
const editorRef = shallowRef<IDomEditor>()

const valueHtml = ref('')

watch(
  () => props.modelValue,
  (val: string) => {
    if (val === unref(valueHtml)) return
    valueHtml.value = val
  }
)

// 监听
watch(
  () => valueHtml.value,
  (val: string) => {
    emit('update:modelValue', val)
  }
)

const handleCreated = (editor: IDomEditor) => {
  editorRef.value = editor
  valueHtml.value = props.modelValue
}

// 自定义图片上传
const customUpload = async (
  file: File,
  insertFn: (url: string, alt: string, href: string) => void
) => {
  const validationError = getUploadMediaValidationError(file, 'image')
  if (validationError) {
    ElMessage.error(validationError)
    return
  }

  try {
    const formData = new FormData()
    formData.append('file', file)

    const res = await uploadImageApi(formData, {
      onUploadProgress: (progressEvent: ProgressEvent) => {
        const percent = progressEvent.total
          ? Math.round((progressEvent.loaded * 100) / progressEvent.total)
          : 0
        // 可以在这里添加上传进度提示
        console.log(`上传进度: ${percent}%`)
      }
    })

    if (res.data?.url) {
      console.log('res.data.url')
      insertFn(res.data.url, file.name, res.data.url)
      ElMessage.success('图片上传成功')
    } else {
      throw new Error('上传失败：未返回图片地址')
    }
  } catch (error: unknown) {
    console.error('图片上传失败:', error)
    if (error instanceof Error) {
      ElMessage.error(getUploadErrorMessage(error, '图片上传失败'))
    }
  }
}

// 自定义视频上传
const customUploadVideo = async (file: File, insertFn: (url: string, poster: string) => void) => {
  const validationError = getUploadMediaValidationError(file, 'video')
  if (validationError) {
    ElMessage.error(validationError)
    return
  }

  try {
    const formData = new FormData()
    formData.append('file', file)
    formData.append('category', 'video') // 标记为视频分类

    const res = await uploadVideoApi(formData, {
      onUploadProgress: (progressEvent: ProgressEvent) => {
        const percent = progressEvent.total
          ? Math.round((progressEvent.loaded * 100) / progressEvent.total)
          : 0
        // 可以在这里添加上传进度提示
        console.log(`视频上传进度: ${percent}%`)
      }
    })

    if (res.data?.url) {
      insertFn(res.data.url, '') // 视频地址，海报留空
      ElMessage.success('视频上传成功')
    } else {
      throw new Error('上传失败：未返回视频地址')
    }
  } catch (error: unknown) {
    console.error('视频上传失败:', error)
    if (error instanceof Error) {
      ElMessage.error(getUploadErrorMessage(error, '视频上传失败'))
    }
  }
}

// 编辑器配置
const editorConfig = computed((): IEditorConfig => {
  return Object.assign(
    {
      readOnly: false,
      customAlert: (s: string, t: string) => {
        switch (t) {
          case 'success':
            ElMessage.success(s)
            break
          case 'info':
            ElMessage.info(s)
            break
          case 'warning':
            ElMessage.warning(s)
            break
          case 'error':
            ElMessage.error(s)
            break
          default:
            ElMessage.info(s)
            break
        }
      },
      autoFocus: false,
      scroll: true,
      MENU_CONF: {
        uploadImage: {
          // 自定义图片上传
          customUpload
        },
        uploadVideo: {
          // 自定义视频上传
          customUpload: customUploadVideo,
          maxFileSize: 100 * 1024 * 1024 // 限制视频大小为 100MB
        }
      }
    },
    props.editorConfig || {}
  )
})

const editorStyle = computed(() => {
  return {
    height: isNumber(props.height) ? `${props.height}px` : props.height
  }
})

// 回调函数
const handleChange = (editor: IDomEditor) => {
  emit('change', editor)
}

// 组件销毁时，及时销毁编辑器
onBeforeUnmount(() => {
  const editor = unref(editorRef.value)

  // 销毁，并移除 editor
  editor?.destroy()
})

const getEditorRef = async (): Promise<IDomEditor> => {
  await nextTick()
  return unref(editorRef.value) as IDomEditor
}

defineExpose({
  getEditorRef
})
</script>

<template>
  <div>
    <div class="border-1 border-solid border-[var(--el-border-color)] z-10">
      <!-- 工具栏 -->
      <Toolbar
        :editor="editorRef"
        :editorId="editorId"
        class="border-0 b-b-1 border-solid border-[var(--el-border-color)]"
      />
      <!-- 编辑器 -->
      <Editor
        v-model="valueHtml"
        :editorId="editorId"
        :defaultConfig="editorConfig"
        :style="editorStyle"
        @on-change="handleChange"
        @on-created="handleCreated"
      />
    </div>
    <div style="color: red; opacity: 0.8">视频上传最大 100MB</div>
  </div>
</template>

<style src="@wangeditor/editor/dist/css/style.css"></style>
