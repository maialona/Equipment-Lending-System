<script setup>
import { computed, onMounted, ref } from 'vue'
import { startOfMonth, subDays, format, isSameDay, isAfter, isBefore, addDays } from 'date-fns'
import { ArrowRightIcon, AlertCircleIcon, CheckCircleIcon, ClockIcon, XIcon } from 'lucide-vue-next'
import { useTransition, TransitionPresets } from '@vueuse/core'

const isMounted = ref(false)
const showLowStockModal = ref(false)
const showPendingModal = ref(false)
const showActiveLoansModal = ref(false)

onMounted(() => {
    // Small delay to ensure transition triggers after render
    setTimeout(() => {
        isMounted.value = true
    }, 100)
})

const props = defineProps({
  orders: {
    type: Array,
    required: true,
    default: () => []
  },
  inventory: {
    type: Array,
    required: true,
    default: () => []
  }
})

const emit = defineEmits(['navigate'])

// --- Layer 1: The Pulse (Metrics) ---

const pendingOrders = computed(() => props.orders.filter(o => o.status === 'PENDING').sort((a, b) => new Date(b.created_at) - new Date(a.created_at)))
const pendingCountSource = computed(() => isMounted.value ? pendingOrders.value.length : 0)
const pendingCount = useTransition(pendingCountSource, { duration: 1500, transition: TransitionPresets.easeOutExpo })

const activeLoansSource = computed(() => props.orders.filter(o => ['APPROVED', 'COMPLETED'].includes(o.status)))
const activeLoansCountSource = computed(() => isMounted.value ? activeLoansSource.value.length : 0)
const activeLoansCount = useTransition(activeLoansCountSource, { duration: 1500, delay: 100, transition: TransitionPresets.easeOutExpo })

// Low Stock Logic:
// If safety_stock is set (not null), check total_stock <= safety_stock
// If safety_stock is null, we assume no alert needed (e.g. fixed assets)
// Note: We used to filter out '空間', now we rely on safety_stock being null for them.
const lowStockItems = computed(() => props.inventory.filter(i => 
    i.safety_stock !== null && 
    i.safety_stock !== undefined && 
    i.total_stock <= i.safety_stock
))
const lowStockCountSource = computed(() => isMounted.value ? lowStockItems.value.length : 0)
const lowStockCount = useTransition(lowStockCountSource, { duration: 1500, delay: 200, transition: TransitionPresets.easeOutExpo })

const monthlyUsageSource = computed(() => {
    if (!isMounted.value) return 0
    const start = startOfMonth(new Date())
    return props.orders.filter(o => new Date(o.created_at) >= start).length
})
const monthlyUsage = useTransition(monthlyUsageSource, { duration: 1500, delay: 300, transition: TransitionPresets.easeOutExpo })

// --- Layer 2: The Trends (Chart & Ranking) ---

// Chart Data (Last 7 Days)
const chartData = computed(() => {
    const days = []
    for (let i = 6; i >= 0; i--) {
        const d = subDays(new Date(), i)
        const dayStr = format(d, 'MM/dd')
        const count = props.orders.filter(o => isSameDay(new Date(o.created_at), d)).length
        days.push({ day: dayStr, value: count })
    }
    return days
})

const maxChartValue = computed(() => Math.max(...chartData.value.map(d => d.value), 5)) // Min max 5 to avoid flat charts

// Ranking Data (Top 5 Items)
const topItems = computed(() => {
    const itemCounts = {}
    props.orders.forEach(order => {
        if (!['REJECTED', 'CANCELLED'].includes(order.status) && order.order_items) {
             order.order_items.forEach(item => {
                 const name = item.item_name_snapshot
                 itemCounts[name] = (itemCounts[name] || 0) + item.quantity
             })
        }
    })
    
    return Object.entries(itemCounts)
        .map(([name, count]) => ({ name, count }))
        .sort((a, b) => b.count - a.count)
        .slice(0, 5)
})

// --- Layer 3: The Feed (Urgent Actions) ---
// Urgent: Pending orders OR Overdue orders
// Let's define "Urgent" as:
// 1. Overdue (End date < Today) AND Not Returned
// 2. Pending (Needs approval)
// 3. Due Soon (End date is Today or Tomorrow)

const feedItems = computed(() => {
    const today = new Date()
    const tomorrow = addDays(today, 1)
    
    const items = []

    props.orders.forEach(order => {
        // Pending
        if (order.status === 'PENDING') {
            items.push({
                type: 'PENDING',
                title: '新申請待審核',
                desc: `${order.applicant_name} 申請借用`,
                date: order.created_at,
                priority: 'high', // Red dot
                orderId: order.id,
                status: 'PENDING'
            })
        }
        
        // Overdue & Active
        if (['APPROVED', 'COMPLETED'].includes(order.status)) {
            const endDate = new Date(order.end_date)
            if (isBefore(endDate, today) && !isSameDay(endDate, today)) {
                 items.push({
                    type: 'OVERDUE',
                    title: '逾期未還',
                    desc: `${order.applicant_name} - ${order.purpose}`,
                    date: order.end_date, // Due date
                    priority: 'critical', 
                    orderId: order.id,
                    status: order.status
                })
            } else if (isSameDay(endDate, today) || isSameDay(endDate, tomorrow)) {
                 items.push({
                    type: 'DUE_SOON',
                    title: '即將到期',
                    desc: `${order.applicant_name} - ${order.end_date} 歸還`,
                    date: order.end_date,
                    priority: 'medium',
                    orderId: order.id,
                    status: order.status
                })
            }
        }
    })

    // Sort by priority/date? 
    // Let's just sort by date descending seems common for feeds, or by urgency.
    // Let's simplified sort: Pending first, then Overdue, then others.
    return items.sort((a, b) => {
        const pMap = { critical: 3, high: 2, medium: 1, low: 0 }
        return pMap[b.priority] - pMap[a.priority]
    }).slice(0, 10) // Limit to 10
})

</script>

<template>
  <div class="flex flex-col gap-6">
      
      <!-- Layer 1: The Pulse -->
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 animate-in fade-in slide-in-from-bottom-4 duration-700 fill-mode-both" style="animation-fill-mode: both;">
          <!-- Pending -->
           <div @click="showPendingModal = true" class="bg-white border border-zinc-200 rounded-xl p-5 flex flex-col justify-between h-32 relative overflow-hidden group cursor-pointer hover:border-zinc-400 transition-colors">
               <div class="flex justify-between items-start">
                   <span class="text-sm font-medium text-zinc-500">待審核申請</span>
                   <div v-if="pendingCount > 0" class="w-2 h-2 rounded-full bg-red-500 animate-pulse"></div>
               </div>
               <div class="text-3xl font-bold text-zinc-900 tracking-tight">
                   {{ Math.round(pendingCount) }}
               </div>
               <div class="absolute bottom-0 right-0 p-4 opacity-5 group-hover:opacity-10 transition-opacity">
                   <AlertCircleIcon class="w-12 h-12 text-zinc-900" />
               </div>
           </div>

           <!-- Active Loans -->
           <div @click="showActiveLoansModal = true" class="bg-white border border-zinc-200 rounded-xl p-5 flex flex-col justify-between h-32 relative overflow-hidden group cursor-pointer hover:border-zinc-400 transition-colors">
               <div class="flex justify-between items-start">
                   <span class="text-sm font-medium text-zinc-500">出借中器材</span>
               </div>
               <div class="text-3xl font-bold text-zinc-900 tracking-tight">
                   {{ Math.round(activeLoansCount) }}
               </div>
               <div class="absolute bottom-0 right-0 p-4 opacity-5 group-hover:opacity-10 transition-opacity">
                   <ClockIcon class="w-12 h-12 text-zinc-900" />
               </div>
           </div>

           <!-- Low Stock -->
           <div @click="showLowStockModal = true" class="bg-white border border-zinc-200 rounded-xl p-5 flex flex-col justify-between h-32 relative overflow-hidden group cursor-pointer hover:border-zinc-400 transition-colors">
               <div class="flex justify-between items-start">
                   <span class="text-sm font-medium text-zinc-500">庫存緊張</span>
                   <div v-if="lowStockCount > 0" class="flex items-center justify-center bg-zinc-100 rounded text-[10px] font-bold px-1.5 py-0.5 text-zinc-600 border border-zinc-200">
                        &le; 3 items
                   </div>
               </div>
               <div class="text-3xl font-bold text-zinc-900 tracking-tight">
                   {{ Math.round(lowStockCount) }}
               </div>
                <!-- Visual usage bar example -->
               <div class="w-full bg-zinc-100 h-1 rounded-full overflow-hidden mt-1">
                   <div class="bg-zinc-900 h-full rounded-full transition-all duration-1000 ease-out" 
                        :style="{ width: isMounted ? (lowStockCountSource / (inventory.length || 1)) * 100 + '%' : '0%' }"></div>
               </div>
           </div>

           <!-- Monthly Usage -->
           <div class="bg-white border border-zinc-200 rounded-xl p-5 flex flex-col justify-between h-32 relative overflow-hidden group">
               <div class="flex justify-between items-start">
                   <span class="text-sm font-medium text-zinc-500">本月總借用次數</span>
               </div>
               <div class="text-3xl font-bold text-zinc-900 tracking-tight">
                   {{ Math.round(monthlyUsage) }}
               </div>
               <div class="absolute bottom-0 right-0 p-4 opacity-5 group-hover:opacity-10 transition-opacity">
                   <CheckCircleIcon class="w-12 h-12 text-zinc-900" />
               </div>
           </div>
      </div>

      <!-- Layer 2: The Trends -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 animate-in fade-in slide-in-from-bottom-4 duration-700 delay-150 fill-mode-both" style="animation-fill-mode: both;">
          
          <!-- Chart -->
          <div class="col-span-1 lg:col-span-2 bg-white border border-zinc-200 rounded-xl p-6 h-80 flex flex-col">
              <div class="mb-6">
                  <h3 class="text-sm font-medium text-zinc-500">借用趨勢 (近7日)</h3>
              </div>
              <div class="flex-1 w-full flex items-end gap-2 sm:gap-4">
                  <div v-for="(day, index) in chartData" :key="index" class="flex-1 flex flex-col items-center gap-2 group">
                      <div class="relative w-full flex items-end justify-center h-48"> <!-- Chart Height -->
                           <!-- Tooltip -->
                           <div class="absolute -top-8 bg-zinc-900 text-white text-xs px-2 py-1 rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap z-10">
                               {{ day.value }} 次
                           </div>
                           
                           <!-- Bar -->
                           <div 
                            class="w-full max-w-[40px] bg-zinc-900 rounded-t-sm transition-all duration-1000 ease-out group-hover:opacity-80"
                            :style="{ height: isMounted ? (day.value / maxChartValue) * 100 + '%' : '0%' }"
                           ></div>
                      </div>
                      <span class="text-xs text-zinc-400 font-mono">{{ day.day }}</span>
                  </div>
              </div>
          </div>

          <!-- Ranking -->
          <div class="col-span-1 bg-white border border-zinc-200 rounded-xl p-6 h-80 flex flex-col">
              <div class="mb-4">
                  <h3 class="text-sm font-medium text-zinc-500">熱門借用排行 Top 5</h3>
              </div>
              <div class="flex-1 overflow-y-auto pr-1">
                  <div v-for="(item, idx) in topItems" :key="idx" class="flex items-center justify-between py-3 border-b border-zinc-50 last:border-0 hover:bg-zinc-50/50 rounded px-1 transition-colors">
                      <div class="flex items-center gap-3">
                          <span class="text-xs font-mono text-zinc-400 w-4">0{{ idx + 1 }}</span>
                          <span class="text-sm font-medium text-zinc-700 truncate max-w-[120px]" :title="item.name">{{ item.name }}</span>
                      </div>
                      <span class="text-sm font-bold text-zinc-900">{{ item.count }}</span>
                  </div>
                  <div v-if="topItems.length === 0" class="h-full flex items-center justify-center text-zinc-300 text-sm">
                      暫無數據
                  </div>
              </div>
          </div>
      </div>

      <!-- Layer 3: The Feed -->
      <div class="bg-white border border-zinc-200 rounded-xl overflow-hidden flex flex-col animate-in fade-in slide-in-from-bottom-4 duration-700 delay-300 fill-mode-both" style="animation-fill-mode: both;">
          <div class="p-6 border-b border-zinc-100 flex justify-between items-center">
              <h3 class="text-sm font-medium text-zinc-500">即時動態</h3>
              <!-- <button class="text-xs font-medium text-zinc-900 hover:underline">查看全部</button> -->
          </div>
          <div class="flex-1">
              <div v-if="feedItems.length === 0" class="p-12 text-center text-zinc-400 text-sm">
                  目前沒有需要緊急處理的事項
              </div>
              <table v-else class="w-full text-left border-collapse">
                  <tbody>
                      <tr v-for="item in feedItems" :key="item.orderId" 
                          @click="emit('navigate', item)"
                          class="border-b border-zinc-50 hover:bg-zinc-50 transition-colors group cursor-pointer">
                          <td class="px-6 py-4 w-12">
                              <div v-if="item.priority === 'critical'" class="w-2 h-2 rounded-full bg-red-500"></div>
                              <div v-else-if="item.priority === 'high'" class="w-2 h-2 rounded-full bg-orange-500"></div>
                              <div v-else class="w-2 h-2 rounded-full bg-zinc-300"></div>
                          </td>
                          <td class="px-6 py-4">
                              <span class="text-sm font-bold text-zinc-900 block mb-0.5">{{ item.title }}</span>
                              <span class="text-xs text-zinc-500">{{ item.desc }}</span>
                          </td>
                          <td class="px-6 py-4 text-right">
                               <span class="text-xs font-mono text-zinc-400 px-2 py-1 rounded bg-zinc-100 border border-zinc-200">{{ format(new Date(item.date), 'yyyy/MM/dd') }}</span>
                          </td>
                          <td class="px-6 py-4 text-right w-24 opacity-0 group-hover:opacity-100 transition-opacity">
                              <button class="p-2 hover:bg-zinc-100 rounded-full transition-colors">
                                <ArrowRightIcon class="w-4 h-4 text-zinc-400" />
                              </button>
                          </td>
                      </tr>
                  </tbody>
              </table>
          </div>
      </div>
      
      <!-- Low Stock Modal -->
      <Teleport to="body">
        <div v-if="showLowStockModal" class="fixed inset-0 z-50 flex items-center justify-center p-4" role="dialog">
            <!-- Backdrop -->
            <div class="absolute inset-0 bg-black/40 backdrop-blur-sm transition-opacity" @click="showLowStockModal = false"></div>
            
            <!-- Modal Content -->
            <div class="relative bg-white rounded-xl shadow-2xl w-full max-w-md overflow-hidden flex flex-col max-h-[80vh] animate-in zoom-in-95 duration-200">
                <div class="px-6 py-4 border-b border-zinc-100 flex items-center justify-between bg-zinc-50/50">
                    <div class="flex items-center gap-2">
                         <div class="w-2 h-2 rounded-full bg-orange-500 animate-pulse"></div>
                         <h3 class="font-bold text-zinc-900">庫存緊張清單</h3>
                    </div>
                    <button @click="showLowStockModal = false" class="p-1 hover:bg-zinc-200 rounded transition-colors text-zinc-500">
                        <XIcon class="w-5 h-5" />
                    </button>
                </div>
                
                <div class="flex-1 overflow-y-auto p-2">
                    <div v-if="lowStockItems.length === 0" class="p-8 text-center text-zinc-400 text-sm">
                        目前沒有庫存緊張的項目
                    </div>
                    <div v-else class="space-y-1">
                        <div v-for="item in lowStockItems" :key="item.id" class="p-3 bg-white hover:bg-zinc-50 rounded-lg border border-zinc-100 transition-colors flex items-center justify-between">
                            <div class="flex items-center gap-3">
                                <span class="px-2 py-1 bg-zinc-100 text-zinc-500 text-[10px] font-mono rounded border border-zinc-200">{{ item.custom_id }}</span>
                                <div class="flex flex-col">
                                    <span class="text-sm font-medium text-zinc-900">{{ item.name }}</span>
                                    <span class="text-xs text-zinc-500">{{ item.category }}</span>
                                </div>
                            </div>
                            <div class="flex items-center gap-1.5">
                                <span class="text-xs text-zinc-400">剩餘</span>
                                <span class="text-sm font-bold text-orange-600 px-2 py-0.5 bg-orange-50 rounded">{{ item.total_stock }}</span>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="p-4 border-t border-zinc-100 bg-zinc-50/50 text-center">
                    <button @click="showLowStockModal = false" class="w-full py-2 bg-white border border-zinc-200 text-zinc-700 font-medium rounded-lg text-sm hover:bg-zinc-50 transition-colors">
                        關閉
                    </button>
                </div>
            </div>
        </div>
      </Teleport>

      <!-- Pending Orders Modal -->
      <Teleport to="body">
        <div v-if="showPendingModal" class="fixed inset-0 z-50 flex items-center justify-center p-4" role="dialog">
            <div class="absolute inset-0 bg-black/40 backdrop-blur-sm transition-opacity" @click="showPendingModal = false"></div>
            <div class="relative bg-white rounded-xl shadow-2xl w-full max-w-md overflow-hidden flex flex-col max-h-[80vh] animate-in zoom-in-95 duration-200">
                <div class="px-6 py-4 border-b border-zinc-100 flex items-center justify-between bg-zinc-50/50">
                    <div class="flex items-center gap-2">
                         <div class="w-2 h-2 rounded-full bg-red-500 animate-pulse"></div>
                         <h3 class="font-bold text-zinc-900">待審核申請</h3>
                    </div>
                    <button @click="showPendingModal = false" class="p-1 hover:bg-zinc-200 rounded transition-colors text-zinc-500">
                        <XIcon class="w-5 h-5" />
                    </button>
                </div>
                <div class="flex-1 overflow-y-auto p-2">
                    <div v-if="pendingOrders.length === 0" class="p-8 text-center text-zinc-400 text-sm">
                        目前沒有待審核的申請
                    </div>
                    <div v-else class="space-y-1">
                        <div v-for="order in pendingOrders" :key="order.id" class="p-3 bg-white hover:bg-zinc-50 rounded-lg border border-zinc-100 transition-colors">
                            <div class="flex justify-between items-start mb-2">
                                <span class="text-sm font-bold text-zinc-900">{{ order.applicant_name }}</span>
                                <span class="text-xs text-zinc-500 font-mono">{{ format(new Date(order.created_at), 'MM/dd HH:mm') }}</span>
                            </div>
                            <div class="space-y-1">
                                <div v-for="item in order.order_items" :key="item.item_custom_id" class="flex justify-between text-xs text-zinc-600">
                                    <span>{{ item.item_name_snapshot }}</span>
                                    <span>x{{ item.quantity }}</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="p-4 border-t border-zinc-100 bg-zinc-50/50 text-center">
                    <button @click="showPendingModal = false" class="w-full py-2 bg-white border border-zinc-200 text-zinc-700 font-medium rounded-lg text-sm hover:bg-zinc-50 transition-colors">關閉</button>
                </div>
            </div>
        </div>
      </Teleport>

      <!-- Active Loans Modal -->
      <Teleport to="body">
        <div v-if="showActiveLoansModal" class="fixed inset-0 z-50 flex items-center justify-center p-4" role="dialog">
            <div class="absolute inset-0 bg-black/40 backdrop-blur-sm transition-opacity" @click="showActiveLoansModal = false"></div>
            <div class="relative bg-white rounded-xl shadow-2xl w-full max-w-md overflow-hidden flex flex-col max-h-[80vh] animate-in zoom-in-95 duration-200">
                <div class="px-6 py-4 border-b border-zinc-100 flex items-center justify-between bg-zinc-50/50">
                    <div class="flex items-center gap-2">
                         <div class="w-2 h-2 rounded-full bg-blue-500 animate-pulse"></div>
                         <h3 class="font-bold text-zinc-900">出借中器材</h3>
                    </div>
                    <button @click="showActiveLoansModal = false" class="p-1 hover:bg-zinc-200 rounded transition-colors text-zinc-500">
                        <XIcon class="w-5 h-5" />
                    </button>
                </div>
                <div class="flex-1 overflow-y-auto p-2">
                    <div v-if="activeLoansSource.length === 0" class="p-8 text-center text-zinc-400 text-sm">
                        目前沒有出借中的器材
                    </div>
                    <div v-else class="space-y-1">
                        <div v-for="order in activeLoansSource" :key="order.id" class="p-3 bg-white hover:bg-zinc-50 rounded-lg border border-zinc-100 transition-colors">
                            <div class="flex justify-between items-start mb-2">
                                <span class="text-sm font-bold text-zinc-900">{{ order.applicant_name }}</span>
                                <span class="text-xs text-zinc-500">歸還日: {{ order.end_date }}</span>
                            </div>
                            <div class="space-y-1">
                                <div v-for="item in order.order_items" :key="item.item_custom_id" class="flex justify-between text-xs text-zinc-600">
                                    <span>{{ item.item_name_snapshot }}</span>
                                    <span>x{{ item.quantity }}</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="p-4 border-t border-zinc-100 bg-zinc-50/50 text-center">
                    <button @click="showActiveLoansModal = false" class="w-full py-2 bg-white border border-zinc-200 text-zinc-700 font-medium rounded-lg text-sm hover:bg-zinc-50 transition-colors">關閉</button>
                </div>
            </div>
        </div>
      </Teleport>
  </div>
</template>
