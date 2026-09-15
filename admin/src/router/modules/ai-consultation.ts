export default {
  path: '/ai-consultation',
  name: 'AiConsultation',
  component: () => import('@/views/ai-consultation/index.vue'),
  redirect: '/ai-consultation/self-check-lists',
  meta: {
    title: 'AI 问诊管理',
    icon: 'ep:chat-dot-round',
    orderNo: 10
  },
  children: [
    {
      path: 'self-check-lists',
      name: 'SelfCheckLists',
      component: () => import('@/views/ai-consultation/self-check-lists/index.vue'),
      meta: {
        title: '自查表管理',
        icon: 'ep:document'
      }
    },
    {
      path: 'config',
      name: 'AiConsultationConfig',
      component: () => import('@/views/ai-consultation/config/index.vue'),
      meta: {
        title: '问诊配置',
        icon: 'ep:setting'
      }
    },
    // 更具体的路由放在前面，避免被 :id 通配符匹配
    {
      path: 'self-check-questions/:id/create',
      name: 'SelfCheckQuestionCreate',
      component: () => import('@/views/ai-consultation/self-check-questions/edit.vue'),
      meta: {
        title: '新增问题',
        hidden: true,
        activeMenu: '/ai-consultation/self-check-lists'
      }
    },
    {
      path: 'self-check-questions/:id/edit/:questionId',
      name: 'SelfCheckQuestionEdit',
      component: () => import('@/views/ai-consultation/self-check-questions/edit.vue'),
      meta: {
        title: '编辑问题',
        hidden: true,
        activeMenu: '/ai-consultation/self-check-lists'
      }
    },
    {
      path: 'self-check-questions/:id',
      name: 'SelfCheckQuestions',
      component: () => import('@/views/ai-consultation/self-check-questions/index.vue'),
      meta: {
        title: '问题管理',
        hidden: true,
        activeMenu: '/ai-consultation/self-check-lists'
      }
    }
  ]
}
