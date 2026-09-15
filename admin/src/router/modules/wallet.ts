/**
 * 钱包审核路由模块
 */
export default {
  path: '/wallet',
  component: () => import('@/utils/routerHelper').then(m => m.Layout),
  redirect: '/wallet/audit',
  name: 'Wallet',
  meta: {
    title: '钱包管理',
    orderNo: 20
  },
  children: [
    {
      path: 'audit',
      component: () => import('@/views/WalletAudit/index.vue'),
      name: 'WalletAudit',
      meta: {
        title: '审核管理',
        noCache: true,
        affix: true
      }
    }
  ]
}
