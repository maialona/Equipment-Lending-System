
import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '../views/HomeView.vue'
import LandingView from '../views/LandingView.vue'
import MeetingRoomView from '../views/MeetingRoomView.vue'
import { useAuthStore } from '../stores/auth'

// Lazy load other views
const CartView = () => import('../views/CartView.vue')
const AdminDashboard = () => import('../views/AdminDashboard.vue')
const ConsumablesView = () => import('../views/ConsumablesView.vue')
const UserDashboardView = () => import('../views/UserDashboardView.vue')

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'landing',
      component: LandingView
    },
    {
      path: '/equipment',
      name: 'home',
      component: HomeView,
      // meta: { requiresAuth: true } // Public now
    },
    {
      path: '/dashboard',
      name: 'dashboard',
      component: UserDashboardView,
      meta: { requiresAuth: true }
    },
    {
      path: '/meeting-rooms',
      name: 'meeting-rooms',
      component: MeetingRoomView,
      // meta: { requiresAuth: true }
    },
    {
      path: '/cart',
      name: 'cart',
      component: CartView,
      // meta: { requiresAuth: true }
    },
    {
      path: '/consumables',
      name: 'consumables',
      component: ConsumablesView,
      // meta: { requiresAuth: true }
    },
    {
      path: '/login', 
      redirect: '/' 
    },
    {
      path: '/admin/login', 
      redirect: '/' 
    },
    {
      path: '/debug',
      name: 'debug',
      component: () => import('../views/DebugView.vue')
    },
    {
      path: '/admin/dashboard',
      name: 'admin-dashboard',
      component: AdminDashboard,
      meta: { requiresAdmin: true }
    }
  ]
})

router.beforeEach((to, from, next) => {
  const authStore = useAuthStore()
  
  // 1. Check for Admin routes
  if (to.meta.requiresAdmin) {
    if (!authStore.isAdmin) {
      if (!authStore.isAuthenticated) {
        return next('/')
      } else {
        return next('/') // Authorized but not admin
      }
    }
  }

  // 2. Check for General Auth routes
  if (to.meta.requiresAuth) {
    if (!authStore.isAuthenticated) {
      return next('/')
    }
  }
  
  next()
})

export default router
