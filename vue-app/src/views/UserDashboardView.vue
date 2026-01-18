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
        <h1 class="text-3xl font-bold text-foreground">我的紀錄</h1>
        <p class="text-muted-foreground mt-2">檢視您的借用狀態與歷史紀錄。</p>
    </div>

    <!-- My Orders Section -->
    <div v-if="auth.isAuthenticated" class="bg-card rounded-lg border border-border overflow-hidden">

       
       <div v-if="myOrders.length === 0" class="p-16 text-center flex flex-col items-center justify-center">
          <div class="text-foreground font-medium mb-1">尚未有借用紀錄</div>
          <p class="text-muted-foreground text-sm mb-6">您目前沒有正在進行中的借用，需要申請器材嗎？</p>
          <RouterLink to="/equipment" class="px-4 py-2 text-sm font-medium text-foreground bg-card border border-border rounded-md hover:bg-muted transition-colors shadow-sm">
             前往器材列表
          </RouterLink>
       </div>

       <div v-else class="overflow-x-auto">
         <table class="min-w-full divide-y divide-border">
           <thead class="bg-muted/50">
              <tr>
                <th class="px-6 py-3 text-left text-[10px] font-bold text-muted-foreground uppercase tracking-wider whitespace-nowrap">日期</th>
                <th class="px-6 py-3 text-left text-[10px] font-bold text-muted-foreground uppercase tracking-wider whitespace-nowrap">項目</th>
                <th class="px-6 py-3 text-left text-[10px] font-bold text-muted-foreground uppercase tracking-wider whitespace-nowrap">用途</th>
                <th class="px-6 py-3 text-left text-[10px] font-bold text-muted-foreground uppercase tracking-wider whitespace-nowrap">狀態</th>
              </tr>
           </thead>
           <tbody class="divide-y divide-border bg-card">
              <tr v-for="order in myOrders" :key="order.id" class="hover:bg-muted/50 transition-colors">
                 <td class="px-6 py-4 text-sm text-foreground whitespace-nowrap">
                    <div class="font-medium">{{ order.start_date }} ~ {{ order.end_date }}</div>
                    <div v-if="order.start_time" class="text-xs text-muted-foreground mt-0.5 font-mono">{{ order.start_time }} - {{ order.end_time }}</div>
                 </td>
                 <td class="px-6 py-4 text-sm text-muted-foreground min-w-[200px]">
                    <ul class="space-y-1">
                       <li v-for="item in order.order_items" :key="item.id">
                          {{ item.item_name_snapshot }} <span class="text-muted-foreground text-xs ml-1">x{{ item.quantity }}</span>
                       </li>
                    </ul>
                 </td>
                 <td class="px-6 py-4 text-sm text-muted-foreground max-w-xs truncate" :title="order.purpose">
                    {{ order.purpose }}
                 </td>
                 <td class="px-6 py-4 whitespace-nowrap">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold border"
                      :class="{
                        'bg-background border-border text-foreground': order.status === 'PENDING',
                        'bg-primary text-primary-foreground border-primary': order.status === 'APPROVED' || order.status === 'COMPLETED',
                        'bg-muted/50 text-muted-foreground border-border line-through': order.status === 'REJECTED' || order.status === 'CANCELLED',
                        'bg-background text-muted-foreground border-border': order.status === 'RETURNED'
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



  </div>
</template>
