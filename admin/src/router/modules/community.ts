/**
 * 社区管理路由模块
 */

export default {
  path: '/community',
  component: () => import('@/utils/routerHelper').then((m) => m.Layout),
  redirect: '/community/pending-review',
  name: 'Community',
  meta: {
    title: '社区管理',
    icon: 'vi-mdi:forum',
    orderNo: 25
  },
  children: [
    {
      path: 'pending-review',
      component: () => import('@/views/Community/PendingReview/index.vue'),
      name: 'PendingReview',
      meta: {
        title: '待审核列表',
        icon: 'vi-mdi:clipboard-text',
        noCache: true,
        affix: true
      }
    },
    {
      path: 'reviewed-content',
      component: () => import('@/views/Community/ReviewedContent/index.vue'),
      name: 'ReviewedContent',
      meta: {
        title: '已审核内容',
        icon: 'vi-mdi:clipboard-check',
        noCache: true
      }
    },
    {
      path: 'reports',
      component: () => import('@/views/Community/Reports/index.vue'),
      name: 'CommunityReports',
      meta: {
        title: '举报处理',
        icon: 'vi-mdi:flag',
        noCache: true
      }
    },
    {
      path: 'sensitive-words',
      component: () => import('@/views/Community/SensitiveWords/index.vue'),
      name: 'SensitiveWords',
      meta: {
        title: '敏感词管理',
        icon: 'vi-mdi:shield-alert',
        noCache: true
      }
    }
  ]
}
