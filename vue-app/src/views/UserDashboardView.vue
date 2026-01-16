<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '../lib/supabase'
import { 
  CubeIcon, 
  HomeIcon, 
  ExclamationTriangleIcon,
  ClockIcon
} from '@heroicons/vue/24/outline'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()

const items = ref([])
const activeOrderItems = ref([])
const upcomingOrders = ref([])
const myOrders = ref([])
const loading = ref(true)

async function fetchData() {
  loading.value = true
  
  // Fetch My Orders
  if (auth.user && auth.user.name) {
      const { data: myOrderData, error: myOrderError } = await supabase
        .from('orders')
        .select(`
            *,
            order_items (
                item_name_snapshot,
                quantity
            )
        `)
        .or(`applicant_name.eq.${auth.user.name},applicant_name.eq.${auth.user.username}`)
        .order('created_at', { ascending: false })
        
      if (myOrderError) console.error('Error fetching my orders:', myOrderError)
      else myOrders.value = myOrderData
  }

  loading.value = false
}

onMounted(() => {
  fetchData()
})
</script>

<template>
  <div class="max-w-6xl mx-auto space-y-8">
    
    <!-- Hero Section -->
    <div>
        <h1 class="text-3xl font-bold text-zinc-900">我的紀錄</h1>
        <p class="text-zinc-500 mt-2">檢視您的借用狀態與歷史紀錄。</p>
    </div>

    <!-- My Orders Section -->
    <div v-if="auth.isAuthenticated" class="bg-white rounded-lg border border-zinc-200 overflow-hidden">

       
       <div v-if="myOrders.length === 0" class="p-16 text-center flex flex-col items-center justify-center">
          <div class="text-zinc-900 font-medium mb-1">尚未有借用紀錄</div>
          <p class="text-zinc-400 text-sm mb-6">您目前沒有正在進行中的借用，需要申請器材嗎？</p>
          <RouterLink to="/equipment" class="px-4 py-2 text-sm font-medium text-zinc-700 bg-white border border-zinc-200 rounded-md hover:bg-zinc-50 hover:text-zinc-900 transition-colors shadow-sm">
             前往器材列表
          </RouterLink>
       </div>

       <table v-else class="min-w-full divide-y divide-zinc-200">
         <thead class="bg-zinc-50">
            <tr>
              <th class="px-6 py-3 text-left text-[10px] font-bold text-zinc-500 uppercase tracking-wider">日期</th>
              <th class="px-6 py-3 text-left text-[10px] font-bold text-zinc-500 uppercase tracking-wider">項目</th>
              <th class="px-6 py-3 text-left text-[10px] font-bold text-zinc-500 uppercase tracking-wider">用途</th>
              <th class="px-6 py-3 text-left text-[10px] font-bold text-zinc-500 uppercase tracking-wider">狀態</th>
            </tr>
         </thead>
         <tbody class="divide-y divide-zinc-100 bg-white">
            <tr v-for="order in myOrders" :key="order.id" class="hover:bg-zinc-50 transition-colors">
               <td class="px-6 py-4 text-sm text-zinc-900">
                  <div class="font-medium">{{ order.start_date }} ~ {{ order.end_date }}</div>
                  <div v-if="order.start_time" class="text-xs text-zinc-500 mt-0.5 font-mono">{{ order.start_time }} - {{ order.end_time }}</div>
               </td>
               <td class="px-6 py-4 text-sm text-zinc-600">
                  <ul class="space-y-1">
                     <li v-for="item in order.order_items" :key="item.id">
                        {{ item.item_name_snapshot }} <span class="text-zinc-400 text-xs ml-1">x{{ item.quantity }}</span>
                     </li>
                  </ul>
               </td>
               <td class="px-6 py-4 text-sm text-zinc-500 max-w-xs truncate" :title="order.purpose">
                  {{ order.purpose }}
               </td>
               <td class="px-6 py-4">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold border"
                    :class="{
                      'bg-white border-zinc-300 text-zinc-700': order.status === 'PENDING',
                      'bg-zinc-900 text-white border-zinc-900': order.status === 'APPROVED' || order.status === 'COMPLETED',
                      'bg-zinc-100 text-zinc-400 border-zinc-200 line-through': order.status === 'REJECTED' || order.status === 'CANCELLED',
                      'bg-white text-zinc-500 border-zinc-200': order.status === 'RETURNED'
                    }">
                     {{ 
                        order.status === 'PENDING' ? '待審核' :
                        order.status === 'APPROVED' ? '已核准' :
                        order.status === 'COMPLETED' ? '已領用' :
                        order.status === 'REJECTED' ? '已拒絕' :
                        order.status === 'RETURNED' ? '已歸還' : order.status
                     }}
                  </span>
               </td>
            </tr>
         </tbody>
       </table>
    </div>



  </div>
</template>
