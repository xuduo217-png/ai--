export default {
  path: '/lost-found',
  name: 'LostFound',
  component: () => import('@/views/LostFound/index.vue'),
  meta: {
    title: '走失招领',
    icon: 'ep:notification',
    orderNo: 20
  }
}
