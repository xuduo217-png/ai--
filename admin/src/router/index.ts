import { createRouter, createWebHashHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'
import type { App } from 'vue'
import { Layout } from '@/utils/routerHelper'
import { useI18n } from '@/hooks/web/useI18n'
import { NO_RESET_WHITE_LIST } from '@/constants'

const { t } = useI18n()

export const constantRouterMap: AppRouteRecordRaw[] = [
  {
    path: '/',
    component: Layout,
    redirect: '/home',
    name: 'Root',
    meta: {
      hidden: true
    }
  },
  {
    path: '/home',
    component: Layout,
    redirect: '/home/index',
    name: 'Home',
    meta: {
      hidden: false
    },
    children: [
      {
        path: 'index',
        component: () => import('@/views/Home/Home.vue'),
        name: 'HomeIndex',
        meta: {
          title: '首页',
          icon: 'vi-mdi:home',
          affix: true
        }
      }
    ]
  },
  {
    path: '/redirect',
    component: Layout,
    name: 'RedirectWrap',
    children: [
      {
        path: '/redirect/:path(.*)',
        name: 'Redirect',
        component: () => import('@/views/Redirect/Redirect.vue'),
        meta: {}
      }
    ],
    meta: {
      hidden: true,
      noTagsView: true
    }
  },
  {
    path: '/login',
    component: () => import('@/views/Login/Login.vue'),
    name: 'Login',
    meta: {
      hidden: true,
      title: t('router.login'),
      noTagsView: true
    }
  },
  {
    path: '/privacy-policy',
    component: () => import('@/views/Public/PrivacyPolicy/index.vue'),
    name: 'PrivacyPolicy',
    meta: {
      hidden: true,
      title: '隐私政策',
      noTagsView: true
    }
  },
  {
    path: '/personal',
    component: Layout,
    redirect: '/personal/personal-center',
    name: 'Personal',
    meta: {
      title: t('router.personal'),
      hidden: true,
      canTo: true
    },
    children: [
      {
        path: 'personal-center',
        component: () => import('@/views/Personal/PersonalCenter/PersonalCenter.vue'),
        name: 'PersonalCenter',
        meta: {
          title: t('router.personalCenter'),
          hidden: true,
          canTo: true
        }
      }
    ]
  },
  {
    path: '/404',
    component: () => import('@/views/Error/404.vue'),
    name: 'NoFind',
    meta: {
      hidden: true,
      title: '404',
      noTagsView: true
    }
  }
]

export const asyncRouterMap: AppRouteRecordRaw[] = [
  // ==================== 基础数据管理 ====================
  {
    path: '/hospitals',
    component: Layout,
    redirect: '/hospitals/list',
    name: 'Hospitals',
    meta: {
      title: '医院管理',
      icon: 'vi-mdi:hospital-building',
      alwaysShow: true
    },
    children: [
      {
        path: 'list',
        component: () => import('@/views/Hospitals/HospitalManagement.vue'),
        name: 'HospitalManagement',
        meta: {
          title: '医院列表',
          noCache: true,
          affix: true
        }
      },
      {
        path: ':id/departments',
        component: () => import('@/views/Hospitals/HospitalDepartmentManagement.vue'),
        name: 'HospitalDepartmentManagement',
        meta: {
          title: '医院科室管理',
          hidden: true,
          canTo: true,
          activeMenu: '/hospitals/list',
          noCache: true
        }
      },
      {
        path: 'doctors/list',
        component: () => import('@/views/Hospitals/Doctors/DoctorList.vue'),
        name: 'DoctorList',
        meta: {
          title: '医生列表',
          noCache: true,
          affix: true
        }
      },
      {
        path: 'doctors/create',
        component: () => import('@/views/Hospitals/Doctors/DoctorForm.vue'),
        name: 'DoctorCreate',
        meta: {
          title: '新增医生',
          hidden: true,
          canTo: true,
          activeMenu: '/hospitals/doctors/list',
          noCache: true
        }
      },
      {
        path: 'doctors/edit/:id',
        component: () => import('@/views/Hospitals/Doctors/DoctorForm.vue'),
        name: 'DoctorEdit',
        meta: {
          title: '编辑医生',
          hidden: true,
          canTo: true,
          activeMenu: '/hospitals/doctors/list',
          noCache: true
        }
      }
    ]
  },
  {
    path: '/users',
    component: Layout,
    redirect: '/users/list',
    name: 'Users',
    meta: {
      title: '用户管理',
      icon: 'vi-mdi:account-multiple',
      alwaysShow: true
    },
    children: [
      {
        path: 'list',
        component: () => import('@/views/Users/UserList.vue'),
        name: 'UserList',
        meta: {
          title: '用户列表',
          noCache: true,
          affix: true
        }
      },
      {
        path: 'wallet-audit',
        redirect: '/wallet/settlements',
        name: 'LegacyWalletAudit',
        meta: {
          title: '收益结算审核',
          hidden: true,
          canTo: true,
          noTagsView: true
        }
      }
    ]
  },
  {
    path: '/wallet',
    component: Layout,
    redirect: '/wallet/transactions',
    name: 'WalletManagement',
    meta: {
      title: '钱包管理',
      icon: 'vi-mdi:wallet',
      alwaysShow: true
    },
    children: [
      {
        path: 'transactions',
        component: () => import('@/views/WalletTransactions/index.vue'),
        name: 'WalletTransactions',
        meta: {
          title: '钱包流水',
          noCache: true
        }
      },
      {
        path: 'settlements',
        component: () => import('@/views/WalletAudit/index.vue'),
        name: 'WalletAudit',
        meta: {
          title: '收益结算审核',
          noCache: true
        }
      },
      {
        path: 'withdrawals',
        component: () => import('@/views/WalletWithdrawals/index.vue'),
        name: 'WalletWithdrawals',
        meta: {
          title: '支付宝提现',
          noCache: true,
          role: ['SUPER_ADMIN']
        }
      }
    ]
  },
  // ==================== 核心业务流程 ====================
  {
    path: '/pets',
    component: Layout,
    redirect: '/pets/list',
    name: 'Pets',
    meta: {
      title: '宠物管理',
      icon: 'vi-mdi:paw',
      alwaysShow: true
    },
    children: [
      {
        path: 'list',
        component: () => import('@/views/Pets/PetList.vue'),
        name: 'PetList',
        meta: {
          title: '宠物列表',
          noCache: true,
          affix: true
        }
      },
      {
        path: 'appointments',
        component: () => import('@/views/Pets/AppointmentList.vue'),
        name: 'HealthAppointments',
        meta: {
          title: '预约管理',
          noCache: true,
          affix: true
        }
      },
      {
        path: 'lost-found',
        component: () => import('@/views/Pets/LostFound.vue'),
        name: 'PetLostFound',
        meta: {
          title: '走失信息',
          noCache: true,
          affix: true
        }
      },
      {
        path: 'categories',
        component: () => import('@/views/Pets/CategoryManagement.vue'),
        name: 'PetCategories',
        meta: {
          title: '类别管理',
          noCache: true,
          affix: true
        }
      }
    ]
  },
  {
    path: '/online-service',
    component: Layout,
    redirect: '/online-service/auto-reply',
    name: 'OnlineService',
    meta: {
      title: '在线医疗服务',
      icon: 'vi-mdi:chat-processing',
      alwaysShow: true
    },
    children: [
      {
        path: 'auto-reply',
        component: () => import('@/views/OnlineService/AutoReplyManagement.vue'),
        name: 'AutoReplyManagement',
        meta: {
          title: '自动回复管理',
          noCache: true,
          affix: true
        }
      },
      {
        path: 'chat-records',
        component: () => import('@/views/chat-records/index.vue'),
        name: 'ChatRecords',
        meta: {
          title: '聊天记录查询',
          noCache: true,
          affix: true
        }
      }
    ]
  },
  {
    path: '/ai-consultation',
    component: Layout,
    redirect: '/ai-consultation/self-check-lists',
    name: 'AiConsultation',
    meta: {
      title: 'AI 问诊管理',
      icon: 'vi-mdi:robot',
      orderNo: 10,
      alwaysShow: true
    },
    children: [
      {
        path: 'self-check-lists',
        name: 'SelfCheckLists',
        component: () => import('@/views/ai-consultation/self-check-lists/index.vue'),
        meta: {
          title: '自查表管理',
          noCache: true,
          affix: true
        }
      },
      {
        path: 'config',
        name: 'AiConsultationConfig',
        component: () => import('@/views/ai-consultation/config/index.vue'),
        meta: {
          title: '问诊配置',
          noCache: true,
          affix: true
        }
      },
      // 更具体的路由放在前面，避免被 :id 通配符匹配
      {
        path: 'diagnosis-reports/detail/:id',
        name: 'AiDiagnosisReportDetail',
        component: () => import('@/views/AiDiagnosisReports/Detail.vue'),
        meta: {
          title: '报告详情',
          hidden: true,
          canTo: true,
          activeMenu: '/ai-consultation/diagnosis-reports',
          noCache: true
        }
      },
      {
        path: 'diagnosis-reports',
        name: 'AiDiagnosisReports',
        component: () => import('@/views/AiDiagnosisReports/index.vue'),
        meta: {
          title: 'AI 问诊报告',
          noCache: true,
          affix: true
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
          canTo: true,
          activeMenu: '/ai-consultation/self-check-lists',
          noCache: true
        }
      },
      {
        path: 'self-check-questions/:id/edit/:questionId',
        name: 'SelfCheckQuestionEdit',
        component: () => import('@/views/ai-consultation/self-check-questions/edit.vue'),
        meta: {
          title: '编辑问题',
          hidden: true,
          canTo: true,
          activeMenu: '/ai-consultation/self-check-lists',
          noCache: true
        }
      },
      {
        path: 'self-check-questions/:id',
        name: 'SelfCheckQuestions',
        component: () => import('@/views/ai-consultation/self-check-questions/index.vue'),
        meta: {
          title: '问题管理',
          hidden: true,
          canTo: true,
          activeMenu: '/ai-consultation/self-check-lists',
          noCache: true
        }
      }
    ]
  },
  // ==================== 增值服务 ====================
  {
    path: '/product',
    component: Layout,
    redirect: '/product/index',
    name: 'Product',
    meta: {
      title: '商品管理',
      icon: 'vi-ant-design:setting-filled',
      alwaysShow: true
    },
    children: [
      {
        path: 'index',
        component: () => import('@/views/Product/Product.vue'),
        name: 'ProductIndex',
        meta: {
          title: '商城商品',
          publishSource: 'ADMIN',
          noCache: true,
          affix: true
        }
      },
      {
        path: 'second-hand',
        component: () => import('@/views/Product/Product.vue'),
        name: 'SecondHandProduct',
        meta: {
          title: '二手商品',
          publishSource: 'USER',
          noCache: true,
          affix: true
        }
      },
      {
        path: 'category',
        component: () => import('@/views/Product/Category.vue'),
        name: 'ProductCategory',
        meta: {
          title: '商品分类',
          noCache: true,
          affix: true
        }
      },
      {
        path: 'audit',
        component: () => import('@/views/Product/ProductAudit.vue'),
        name: 'ProductAudit',
        meta: {
          title: '商品审核',
          noCache: true,
          affix: true
        }
      },
      {
        path: 'coupon',
        component: () => import('@/views/Product/CouponNew.vue'),
        name: 'ProductCoupon',
        meta: {
          title: '优惠券管理',
          noCache: true,
          affix: true
        }
      },
      {
        path: 'hot-products',
        component: () => import('@/views/Product/HotProductsConfig.vue'),
        name: 'ProductHotProductsConfig',
        meta: {
          title: '热门商品配置',
          noCache: true
        }
      },
      {
        path: 'banners',
        component: () => import('@/views/Product/BannerConfig.vue'),
        name: 'ProductBannerConfig',
        meta: {
          title: 'Banner 管理',
          noCache: true
        }
      },
      {
        path: 'form',
        component: () => import('@/views/Product/ProductForm.vue'),
        name: 'ProductForm',
        meta: {
          title: '商品表单',
          hidden: true,
          canTo: true,
          activeMenu: '/product/index'
        }
      },
      {
        path: 'form/:id',
        component: () => import('@/views/Product/ProductForm.vue'),
        name: 'ProductFormEdit',
        meta: {
          title: '编辑商品',
          hidden: true,
          canTo: true,
          activeMenu: '/product/index'
        }
      }
    ]
  },
  // ==================== 订单管理 ====================
  {
    path: '/orders',
    component: Layout,
    redirect: '/orders/list',
    name: 'OrdersGroup',
    meta: {
      title: '订单管理',
      icon: 'vi-mdi:cart'
    },
    children: [
      {
        path: 'list',
        component: () => import('@/views/Order/index.vue'),
        name: 'OrderList',
        meta: {
          title: '订单列表',
          icon: 'vi-mdi:cart-outline'
        }
      },
      {
        path: 'after-sales',
        component: () => import('@/views/OrderAfterSales/index.vue'),
        name: 'OrderAfterSales',
        meta: {
          title: '售后管理',
          icon: 'vi-mdi:clipboard-text-clock-outline'
        }
      },
      {
        path: 'after-sales/:id',
        component: () => import('@/views/OrderAfterSales/detail.vue'),
        name: 'OrderAfterSaleDetail',
        meta: {
          title: '售后详情',
          hidden: true,
          canTo: true,
          activeMenu: '/orders/after-sales'
        }
      }
    ]
  },
  {
    path: '/health-articles',
    component: Layout,
    redirect: '/health-articles/list',
    name: 'HealthArticles',
    meta: {
      title: '健康知识',
      icon: 'vi-mdi:book-open-page-variant',
      alwaysShow: true
    },
    children: [
      {
        path: 'list',
        component: () => import('@/views/HealthArticles/HealthArticleManagement.vue'),
        name: 'HealthArticleManagement',
        meta: {
          title: '文章管理',
          noCache: true,
          affix: true
        }
      },
      {
        path: 'create',
        component: () => import('@/views/HealthArticles/HealthArticleCreate.vue'),
        name: 'HealthArticleCreate',
        meta: {
          title: '新建文章',
          noCache: true,
          hidden: true,
          canTo: true,
          activeMenu: '/health-articles/list'
        }
      },
      {
        path: 'categories',
        component: () => import('@/views/HealthArticles/HealthCategoryManagement.vue'),
        name: 'HealthCategoryManagement',
        meta: {
          title: '分类管理',
          noCache: true,
          affix: true
        }
      }
    ]
  },
  {
    path: '/aid-guides',
    component: Layout,
    redirect: '/aid-guides/categories',
    name: 'AidGuides',
    meta: {
      title: '急救指南',
      icon: 'vi-ant-design:medicine-box-outlined',
      role: ['SUPER_ADMIN']
    },
    children: [
      {
        path: 'categories',
        component: () => import('@/views/AidGuides/AidGuideCategoryManagement.vue'),
        name: 'AidGuideCategories',
        meta: {
          title: '急救指南分类',
          role: ['SUPER_ADMIN']
        }
      },
      {
        path: 'list',
        component: () => import('@/views/AidGuides/AidGuideManagement.vue'),
        name: 'AidGuideManagement',
        meta: {
          title: '指南管理',
          role: ['SUPER_ADMIN']
        }
      },
      {
        path: 'create',
        component: () => import('@/views/AidGuides/AidGuideCreate.vue'),
        name: 'AidGuideCreate',
        meta: {
          title: '新建指南',
          role: ['SUPER_ADMIN'],
          hidden: true,
          canTo: true,
          activeMenu: '/aid-guides/list'
        }
      }
    ]
  },
  // ==================== 好友管理 ====================
  {
    path: '/friends',
    component: Layout,
    redirect: '/friends/statistics',
    name: 'Friends',
    meta: {
      title: '好友管理',
      icon: 'vi-mdi:account-multiple',
      alwaysShow: true
    },
    children: [
      {
        path: 'statistics',
        component: () => import('@/views/friends/statistics/index.vue'),
        name: 'FriendsStatistics',
        meta: {
          title: '数据统计',
          noCache: true,
          affix: true
        }
      },
      {
        path: 'friendships',
        component: () => import('@/views/friends/friendships/index.vue'),
        name: 'Friendships',
        meta: {
          title: '好友关系',
          noCache: true
        }
      },
      {
        path: 'requests',
        component: () => import('@/views/friends/requests/index.vue'),
        name: 'FriendRequests',
        meta: {
          title: '好友申请',
          noCache: true
        }
      },
      {
        path: 'messages',
        component: () => import('@/views/friends/messages/index.vue'),
        name: 'FriendMessages',
        meta: {
          title: '消息记录',
          noCache: true
        }
      },
      {
        path: 'offline-messages',
        component: () => import('@/views/friends/offline-messages/index.vue'),
        name: 'OfflineMessages',
        meta: {
          title: '离线消息队列',
          noCache: true
        }
      }
    ]
  },
  // ==================== 善行计划 ====================
  {
    path: '/good-deeds',
    component: Layout,
    redirect: '/good-deeds/charity',
    name: 'GoodDeeds',
    meta: {
      title: '善行计划',
      icon: 'vi-mdi:charity',
      alwaysShow: true
    },
    children: [
      {
        path: 'charity',
        component: () => import('@/views/GoodDeeds/Charity/index.vue'),
        name: 'CharityList',
        meta: {
          title: '公益管理',
          noCache: true,
          affix: true
        }
      },
      {
        path: 'activities',
        component: () => import('@/views/GoodDeeds/Activities/index.vue'),
        name: 'ActivitiesList',
        meta: {
          title: '活动管理',
          noCache: true
        }
      },
      {
        path: 'activities/create',
        component: () => import('@/views/GoodDeeds/Activities/index.vue'),
        name: 'ActivityCreate',
        meta: {
          title: '新增活动',
          hidden: true,
          canTo: true,
          activeMenu: '/good-deeds/activities',
          noCache: true
        }
      },
      {
        path: 'activities/edit/:id',
        component: () => import('@/views/GoodDeeds/Activities/index.vue'),
        name: 'ActivityEdit',
        meta: {
          title: '编辑活动',
          hidden: true,
          canTo: true,
          activeMenu: '/good-deeds/activities',
          noCache: true
        }
      }
    ]
  },
  // ==================== 社区管理 ====================
  {
    path: '/community',
    component: Layout,
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
  },
  // ==================== 系统管理 ====================
  {
    path: '/system-configs',
    component: Layout,
    redirect: '/system-configs/system-configs',
    name: 'SystemConfigsGroup',
    meta: {
      title: '系统配置',
      icon: 'vi-mdi:cog',
      alwaysShow: true
    },
    children: [
      {
        path: 'system-configs',
        component: () => import('@/views/SystemConfigs/index.vue'),
        name: 'SystemConfigs',
        meta: {
          title: '系统配置'
        }
      },
      {
        path: 'system-articles',
        component: () => import('@/views/SystemConfigs/SystemArticles.vue'),
        name: 'SystemArticles',
        meta: {
          title: '系统文章'
        }
      },
      {
        path: 'logistics',
        component: () => import('@/views/Logistics/index.vue'),
        name: 'Logistics',
        meta: {
          title: '物流管理'
        }
      }
    ]
  }

  // {
  //   path: '/system',
  //   component: Layout,
  //   redirect: '/system/dashboard/analysis',
  //   name: 'System',
  //   meta: {
  //     title: '系统管理',
  //     icon: 'vi-ant-design:setting-filled',
  //     alwaysShow: true
  //   },
  //   children: [
  //     {
  //       path: 'dashboard',
  //       component: Layout,
  //       redirect: '/system/dashboard/analysis',
  //       name: 'Dashboard',
  //       meta: {
  //         title: t('router.dashboard'),
  //         icon: 'vi-ant-design:dashboard-filled',
  //         alwaysShow: true
  //       },
  //       children: [
  //         {
  //           path: 'analysis',
  //           component: () => import('@/views/Management/Dashboard/Analysis.vue'),
  //           name: 'Analysis',
  //           meta: {
  //             title: t('router.analysis'),
  //             noCache: true,
  //             affix: true
  //           }
  //         },
  //         {
  //           path: 'workplace',
  //           component: () => import('@/views/Management/Dashboard/Workplace.vue'),
  //           name: 'Workplace',
  //           meta: {
  //             title: t('router.workplace'),
  //             noCache: true
  //           }
  //         }
  //       ]
  //     },
  //     {
  //       path: 'external-link',
  //       component: Layout,
  //       meta: {},
  //       name: 'ExternalLink',
  //       children: [
  //         {
  //           path: 'https://element-plus-admin-doc.cn/',
  //           name: 'DocumentLink',
  //           meta: {
  //             title: t('router.document'),
  //             icon: 'vi-clarity:document-solid'
  //           }
  //         }
  //       ]
  //     },
  //     {
  //       path: 'guide',
  //       component: Layout,
  //       name: 'Guide',
  //       meta: {},
  //       children: [
  //         {
  //           path: 'index',
  //           component: () => import('@/views/Management/Guide/Guide.vue'),
  //           name: 'GuideDemo',
  //           meta: {
  //             title: t('router.guide'),
  //             icon: 'vi-cib:telegram-plane'
  //           }
  //         }
  //       ]
  //     },
  //     {
  //       path: 'components',
  //       component: Layout,
  //       name: 'ComponentsDemo',
  //       meta: {
  //         title: t('router.component'),
  //         icon: 'vi-bx:bxs-component',
  //         alwaysShow: true
  //       },
  //       children: [
  //         {
  //           path: 'form',
  //           component: getParentLayout(),
  //           redirect: '/system/components/form/default-form',
  //           name: 'Form',
  //           meta: {
  //             title: t('router.form'),
  //             alwaysShow: true
  //           },
  //           children: [
  //             {
  //               path: 'default-form',
  //               component: () => import('@/views/Management/Components/Form/DefaultForm.vue'),
  //               name: 'DefaultForm',
  //               meta: {
  //                 title: t('router.defaultForm')
  //               }
  //             },
  //             {
  //               path: 'use-form',
  //               component: () => import('@/views/Management/Components/Form/UseFormDemo.vue'),
  //               name: 'UseForm',
  //               meta: {
  //                 title: 'UseForm'
  //               }
  //             }
  //           ]
  //         },
  //         {
  //           path: 'table',
  //           component: getParentLayout(),
  //           redirect: '/system/components/table/default-table',
  //           name: 'TableDemo',
  //           meta: {
  //             title: t('router.table'),
  //             alwaysShow: true
  //           },
  //           children: [
  //             {
  //               path: 'default-table',
  //               component: () => import('@/views/Management/Components/Table/DefaultTable.vue'),
  //               name: 'DefaultTable',
  //               meta: {
  //                 title: t('router.defaultTable')
  //               }
  //             },
  //             {
  //               path: 'use-table',
  //               component: () => import('@/views/Management/Components/Table/UseTableDemo.vue'),
  //               name: 'UseTable',
  //               meta: {
  //                 title: 'UseTable'
  //               }
  //             },
  //             {
  //               path: 'tree-table',
  //               component: () => import('@/views/Management/Components/Table/TreeTable.vue'),
  //               name: 'TreeTable',
  //               meta: {
  //                 title: t('router.treeTable')
  //               }
  //             },
  //             {
  //               path: 'table-image-preview',
  //               component: () =>
  //                 import('@/views/Management/Components/Table/TableImagePreview.vue'),
  //               name: 'TableImagePreview',
  //               meta: {
  //                 title: t('router.PicturePreview')
  //               }
  //             },
  //             {
  //               path: 'table-video-preview',
  //               component: () =>
  //                 import('@/views/Management/Components/Table/TableVideoPreview.vue'),
  //               name: 'TableVideoPreview',
  //               meta: {
  //                 title: t('router.tableVideoPreview')
  //               }
  //             },
  //             {
  //               path: 'card-table',
  //               component: () => import('@/views/Management/Components/Table/CardTable.vue'),
  //               name: 'CardTable',
  //               meta: {
  //                 title: t('router.cardTable')
  //               }
  //             }
  //           ]
  //         },
  //         {
  //           path: 'editor-demo',
  //           component: getParentLayout(),
  //           redirect: '/system/components/editor-demo/editor',
  //           name: 'EditorDemo',
  //           meta: {
  //             title: t('router.editor'),
  //             alwaysShow: true
  //           },
  //           children: [
  //             {
  //               path: 'editor',
  //               component: () => import('@/views/Management/Components/Editor/Editor.vue'),
  //               name: 'Editor',
  //               meta: {
  //                 title: t('router.richText')
  //               }
  //             },
  //             {
  //               path: 'json-editor',
  //               component: () => import('@/views/Management/Components/Editor/JsonEditor.vue'),
  //               name: 'JsonEditor',
  //               meta: {
  //                 title: t('router.jsonEditor')
  //               }
  //             }
  //           ]
  //         },
  //         {
  //           path: 'search',
  //           component: () => import('@/views/Management/Components/Search.vue'),
  //           name: 'Search',
  //           meta: {
  //             title: t('router.search')
  //           }
  //         },
  //         {
  //           path: 'descriptions',
  //           component: () => import('@/views/Management/Components/Descriptions.vue'),
  //           name: 'Descriptions',
  //           meta: {
  //             title: t('router.descriptions')
  //           }
  //         },
  //         {
  //           path: 'image-viewer',
  //           component: () => import('@/views/Management/Components/ImageViewer.vue'),
  //           name: 'ImageViewer',
  //           meta: {
  //             title: t('router.imageViewer')
  //           }
  //         },
  //         {
  //           path: 'dialog',
  //           component: () => import('@/views/Management/Components/Dialog.vue'),
  //           name: 'Dialog',
  //           meta: {
  //             title: t('router.dialog')
  //           }
  //         },
  //         {
  //           path: 'icon',
  //           component: () => import('@/views/Management/Components/Icon.vue'),
  //           name: 'Icon',
  //           meta: {
  //             title: t('router.icon')
  //           }
  //         },
  //         {
  //           path: 'icon-picker',
  //           component: () => import('@/views/Management/Components/IconPicker.vue'),
  //           name: 'IconPicker',
  //           meta: {
  //             title: t('router.iconPicker')
  //           }
  //         },
  //         {
  //           path: 'echart',
  //           component: () => import('@/views/Management/Components/Echart.vue'),
  //           name: 'Echart',
  //           meta: {
  //             title: t('router.echart')
  //           }
  //         },
  //         {
  //           path: 'count-to',
  //           component: () => import('@/views/Management/Components/CountTo.vue'),
  //           name: 'CountTo',
  //           meta: {
  //             title: t('router.countTo')
  //           }
  //         },
  //         {
  //           path: 'qrcode',
  //           component: () => import('@/views/Management/Components/Qrcode.vue'),
  //           name: 'Qrcode',
  //           meta: {
  //             title: t('router.qrcode')
  //           }
  //         },
  //         {
  //           path: 'highlight',
  //           component: () => import('@/views/Management/Components/Highlight.vue'),
  //           name: 'Highlight',
  //           meta: {
  //             title: t('router.highlight')
  //           }
  //         },
  //         {
  //           path: 'infotip',
  //           component: () => import('@/views/Management/Components/Infotip.vue'),
  //           name: 'Infotip',
  //           meta: {
  //             title: t('router.infotip')
  //           }
  //         },
  //         {
  //           path: 'input-password',
  //           component: () => import('@/views/Management/Components/InputPassword.vue'),
  //           name: 'InputPassword',
  //           meta: {
  //             title: t('router.inputPassword')
  //           }
  //         },
  //         {
  //           path: 'waterfall',
  //           component: () => import('@/views/Management/Components/Waterfall.vue'),
  //           name: 'waterfall',
  //           meta: {
  //             title: t('router.waterfall')
  //           }
  //         },
  //         {
  //           path: 'image-cropping',
  //           component: () => import('@/views/Management/Components/ImageCropping.vue'),
  //           name: 'ImageCropping',
  //           meta: {
  //             title: t('router.imageCropping')
  //           }
  //         },
  //         {
  //           path: 'video-player',
  //           component: () => import('@/views/Management/Components/VideoPlayer.vue'),
  //           name: 'VideoPlayer',
  //           meta: {
  //             title: t('router.videoPlayer')
  //           }
  //         },
  //         {
  //           path: 'avatars',
  //           component: () => import('@/views/Management/Components/Avatars.vue'),
  //           name: 'Avatars',
  //           meta: {
  //             title: t('router.avatars')
  //           }
  //         },
  //         {
  //           path: 'i-agree',
  //           component: () => import('@/views/Management/Components/IAgree.vue'),
  //           name: 'IAgree',
  //           meta: {
  //             title: t('router.iAgree')
  //           }
  //         }
  //       ]
  //     },
  //     {
  //       path: 'function',
  //       component: Layout,
  //       redirect: '/system/function/multipleTabs',
  //       name: 'Function',
  //       meta: {
  //         title: t('router.function'),
  //         icon: 'vi-ri:function-fill',
  //         alwaysShow: true
  //       },
  //       children: [
  //         {
  //           path: 'multiple-tabs',
  //           component: () => import('@/views/Management/Function/MultipleTabs.vue'),
  //           name: 'MultipleTabs',
  //           meta: {
  //             title: t('router.multipleTabs')
  //           }
  //         },
  //         {
  //           path: 'multiple-tabs-demo/:id',
  //           component: () => import('@/views/Management/Function/MultipleTabsDemo.vue'),
  //           name: 'MultipleTabsDemo',
  //           meta: {
  //             hidden: true,
  //             title: t('router.details'),
  //             canTo: true,
  //             activeMenu: '/system/function/multiple-tabs'
  //           }
  //         },
  //         {
  //           path: 'request',
  //           component: () => import('@/views/Management/Function/Request.vue'),
  //           name: 'Request',
  //           meta: {
  //             title: t('router.request')
  //           }
  //         },
  //         {
  //           path: 'test',
  //           component: () => import('@/views/Management/Function/Test.vue'),
  //           name: 'Test',
  //           meta: {
  //             title: t('router.permission'),
  //             permission: ['add', 'edit', 'delete']
  //           }
  //         }
  //       ]
  //     },
  //     {
  //       path: 'hooks',
  //       component: Layout,
  //       redirect: '/system/hooks/useWatermark',
  //       name: 'Hooks',
  //       meta: {
  //         title: 'hooks',
  //         icon: 'vi-ic:outline-webhook',
  //         alwaysShow: true
  //       },
  //       children: [
  //         {
  //           path: 'useWatermark',
  //           component: () => import('@/views/Management/hooks/useWatermark.vue'),
  //           name: 'UseWatermark',
  //           meta: {
  //             title: 'useWatermark'
  //           }
  //         },
  //         {
  //           path: 'useTagsView',
  //           component: () => import('@/views/Management/hooks/useTagsView.vue'),
  //           name: 'UseTagsView',
  //           meta: {
  //             title: 'useTagsView'
  //           }
  //         },
  //         {
  //           path: 'useValidator',
  //           component: () => import('@/views/Management/hooks/useValidator.vue'),
  //           name: 'UseValidator',
  //           meta: {
  //             title: 'useValidator'
  //           }
  //         },
  //         {
  //           path: 'useCrudSchemas',
  //           component: () => import('@/views/Management/hooks/useCrudSchemas.vue'),
  //           name: 'UseCrudSchemas',
  //           meta: {
  //             title: 'useCrudSchemas'
  //           }
  //         },
  //         {
  //           path: 'useClipboard',
  //           component: () => import('@/views/Management/hooks/useClipboard.vue'),
  //           name: 'UseClipboard',
  //           meta: {
  //             title: 'useClipboard'
  //           }
  //         },
  //         {
  //           path: 'useNetwork',
  //           component: () => import('@/views/Management/hooks/useNetwork.vue'),
  //           name: 'UseNetwork',
  //           meta: {
  //             title: 'useNetwork'
  //           }
  //         }
  //       ]
  //     },
  //     {
  //       path: 'level',
  //       component: Layout,
  //       redirect: '/system/level/menu1/menu1-1/menu1-1-1',
  //       name: 'Level',
  //       meta: {
  //         title: t('router.level'),
  //         icon: 'vi-carbon:skill-level-advanced'
  //       },
  //       children: [
  //         {
  //           path: 'menu1',
  //           name: 'Menu1',
  //           component: getParentLayout(),
  //           redirect: '/system/level/menu1/menu1-1/menu1-1-1',
  //           meta: {
  //             title: t('router.menu1')
  //           },
  //           children: [
  //             {
  //               path: 'menu1-1',
  //               name: 'Menu11',
  //               component: getParentLayout(),
  //               redirect: '/system/level/menu1/menu1-1/menu1-1-1',
  //               meta: {
  //                 title: t('router.menu11'),
  //                 alwaysShow: true
  //               },
  //               children: [
  //                 {
  //                   path: 'menu1-1-1',
  //                   name: 'Menu111',
  //                   component: () => import('@/views/Management/Level/Menu111.vue'),
  //                   meta: {
  //                     title: t('router.menu111')
  //                   }
  //                 }
  //               ]
  //             },
  //             {
  //               path: 'menu1-2',
  //               name: 'Menu12',
  //               component: () => import('@/views/Management/Level/Menu12.vue'),
  //               meta: {
  //                 title: t('router.menu12')
  //               }
  //             }
  //           ]
  //         },
  //         {
  //           path: 'menu2',
  //           name: 'Menu2',
  //           component: () => import('@/views/Management/Level/Menu2.vue'),
  //           meta: {
  //             title: t('router.menu2')
  //           }
  //         }
  //       ]
  //     },
  //     {
  //       path: 'example',
  //       component: Layout,
  //       redirect: '/system/example/example-dialog',
  //       name: 'Example',
  //       meta: {
  //         title: t('router.example'),
  //         icon: 'vi-ep:management',
  //         alwaysShow: true
  //       },
  //       children: [
  //         {
  //           path: 'example-dialog',
  //           component: () => import('@/views/Management/Example/Dialog/ExampleDialog.vue'),
  //           name: 'ExampleDialog',
  //           meta: {
  //             title: t('router.exampleDialog')
  //           }
  //         },
  //         {
  //           path: 'example-page',
  //           component: () => import('@/views/Management/Example/Page/ExamplePage.vue'),
  //           name: 'ExamplePage',
  //           meta: {
  //             title: t('router.examplePage')
  //           }
  //         },
  //         {
  //           path: 'example-add',
  //           component: () => import('@/views/Management/Example/Page/ExampleAdd.vue'),
  //           name: 'ExampleAdd',
  //           meta: {
  //             title: t('router.exampleAdd'),
  //             noTagsView: true,
  //             noCache: true,
  //             hidden: true,
  //             canTo: true,
  //             activeMenu: '/system/example/example-page'
  //           }
  //         },
  //         {
  //           path: 'example-edit',
  //           component: () => import('@/views/Management/Example/Page/ExampleEdit.vue'),
  //           name: 'ExampleEdit',
  //           meta: {
  //             title: t('router.exampleEdit'),
  //             noTagsView: true,
  //             noCache: true,
  //             hidden: true,
  //             canTo: true,
  //             activeMenu: '/system/example/example-page'
  //           }
  //         },
  //         {
  //           path: 'example-detail',
  //           component: () => import('@/views/Management/Example/Page/ExampleDetail.vue'),
  //           name: 'ExampleDetail',
  //           meta: {
  //             title: t('router.exampleDetail'),
  //             noTagsView: true,
  //             noCache: true,
  //             hidden: true,
  //             canTo: true,
  //             activeMenu: '/system/example/example-page'
  //           }
  //         }
  //       ]
  //     },
  //     {
  //       path: 'error',
  //       component: Layout,
  //       redirect: '/system/error/404-demo',
  //       name: 'Error',
  //       meta: {
  //         title: t('router.errorPage'),
  //         icon: 'vi-ci:error',
  //         alwaysShow: true
  //       },
  //       children: [
  //         {
  //           path: '404-demo',
  //           component: () => import('@/views/Error/404.vue'),
  //           name: '404Demo',
  //           meta: {
  //             title: '404'
  //           }
  //         },
  //         {
  //           path: '403-demo',
  //           component: () => import('@/views/Error/403.vue'),
  //           name: '403Demo',
  //           meta: {
  //             title: '403'
  //           }
  //         },
  //         {
  //           path: '500-demo',
  //           component: () => import('@/views/Error/500.vue'),
  //           name: '500Demo',
  //           meta: {
  //             title: '500'
  //           }
  //         }
  //       ]
  //     },
  //     {
  //       path: 'authorization',
  //       component: Layout,
  //       redirect: '/system/authorization/user',
  //       name: 'Authorization',
  //       meta: {
  //         title: t('router.authorization'),
  //         icon: 'vi-eos-icons:role-binding',
  //         alwaysShow: true
  //       },
  //       children: [
  //         {
  //           path: 'department',
  //           component: () => import('@/views/Management/Authorization/Department/Department.vue'),
  //           name: 'Department',
  //           meta: {
  //             title: t('router.department')
  //           }
  //         },
  //         {
  //           path: 'user',
  //           component: () => import('@/views/Management/Authorization/User/User.vue'),
  //           name: 'User',
  //           meta: {
  //             title: t('router.user')
  //           }
  //         },
  //         {
  //           path: 'menu',
  //           component: () => import('@/views/Management/Authorization/Menu/Menu.vue'),
  //           name: 'Menu',
  //           meta: {
  //             title: t('router.menuManagement')
  //           }
  //         },
  //         {
  //           path: 'role',
  //           component: () => import('@/views/Management/Authorization/Role/Role.vue'),
  //           name: 'Role',
  //           meta: {
  //             title: t('router.role')
  //           }
  //         }
  //       ]
  //     }
  //   ]
  // }
]

const router = createRouter({
  history: createWebHashHistory(),
  strict: true,
  routes: constantRouterMap as RouteRecordRaw[],
  scrollBehavior: () => ({ left: 0, top: 0 })
})

export const resetRouter = (): void => {
  router.getRoutes().forEach((route) => {
    const { name } = route
    if (name && !NO_RESET_WHITE_LIST.includes(name as string)) {
      router.hasRoute(name) && router.removeRoute(name)
    }
  })
}

export const setupRouter = (app: App<Element>) => {
  app.use(router)
}

export default router
