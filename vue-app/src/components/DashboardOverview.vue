<script setup>
import { computed, onMounted, ref } from 'vue'
import { startOfMonth, isSameMonth, subDays, format, isSameDay, isAfter, isBefore, addDays } from 'date-fns'
import { ArrowRightIcon, AlertCircleIcon, CheckCircleIcon, ClockIcon, XIcon, TrendingUp, PieChart as PieChartIcon } from 'lucide-vue-next'
import { useTransition, TransitionPresets, useIntersectionObserver } from '@vueuse/core'
import { Doughnut, Line, Bar } from 'vue-chartjs'
import { Chart as ChartJS, ArcElement, Tooltip, Legend, CategoryScale, LinearScale, PointElement, LineElement, Title, BarElement, Filler } from 'chart.js'

import { useDark } from '@vueuse/core'

ChartJS.register(ArcElement, Tooltip, Legend, CategoryScale, LinearScale, PointElement, LineElement, Title, BarElement, Filler)

const isDark = useDark()

const isMounted = ref(false)
const showLowStockModal = ref(false)
const showPendingModal = ref(false)
const showActiveLoansModal = ref(false)
const trendPeriod = ref('7d')

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

const monthlyUsage = computed(() => {
    // Determine month based on period, defaulting to current
    const now = new Date();
    return props.orders.filter(o => isSameMonth(new Date(o.created_at), now)).length
})

// Interaction State for Center Text
const hoveredInventoryItem = ref(null) // { label, value } or null

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



// --- Charts Data ---

const inventoryDistribution = computed(() => {
    const counts = {}
    props.inventory.forEach(item => {
        const cat = item.category || '未分類'
        counts[cat] = (counts[cat] || 0) + item.total_stock
    })
    
    // Sort and Top 5 + Others
    const sorted = Object.entries(counts).sort((a, b) => b[1] - a[1])
    const labels = []
    const data = []
    
    // Limit to 5 for better legibility (User requested Top 5)
    const limit = 5;
    
    sorted.slice(0, limit).forEach(([cat, count]) => {
        labels.push(cat)
        data.push(count)
    })
    
    if (sorted.length > limit) {
        labels.push('其他')
        data.push(sorted.slice(limit).reduce((acc, curr) => acc + curr[1], 0))
    }

    // Calculate actual total stock
    const totalInventoryStock = props.inventory.reduce((acc, curr) => acc + curr.total_stock, 0)

    return {
        labels,
        totalStock: totalInventoryStock, 
        datasets: [{
            backgroundColor: isDark.value 
                ? ['#ffffff', '#a1a1aa', '#71717a', '#52525b', '#3f3f46', '#27272a'] 
                : ['#000000', '#52525b', '#71717a', '#a1a1aa', '#d4d4d8', '#e4e4e7'], 
            data,
            borderColor: isDark.value ? '#18181b' : '#ffffff', // Explicitly use Card BG Hex
            borderWidth: 3,
            hoverOffset: 4
        }]
    }
})

const borrowingTrend = computed(() => {
    const days = []
    const data = []
    
    for (let i = 13; i >= 0; i--) { // Last 14 days
        const d = subDays(new Date(), i)
        days.push(format(d, 'MM/dd'))
        const count = props.orders.filter(o => isSameDay(new Date(o.created_at), d)).length
        data.push(count)
    }

    return {
        labels: days,
        datasets: [{
            label: '申請數',
            backgroundColor: (ctx) => {
                const canvas = ctx.chart.ctx;
                const gradient = canvas.createLinearGradient(0, 0, 0, 300);
                
                // Use explicit line colors for gradient base
                const color = isDark.value ? '255, 255, 255' : '0, 0, 0'; 
                
                gradient.addColorStop(0, `rgba(${color}, 0.2)`); // Top 20% opacity
                gradient.addColorStop(1, `rgba(${color}, 0)`);   // Bottom transparent
                return gradient;
            },
            borderColor: isDark.value ? '#ffffff' : '#000000', // White in Dark, Black in Light
            data,
            tension: 0.4,
            pointRadius: 0, // Minimize points
            pointHoverRadius: 4,
            pointBackgroundColor: isDark.value ? '#ffffff' : '#000000',
            pointBorderColor: isDark.value ? '#ffffff' : '#000000',
            pointBorderWidth: 2,
            fill: true
        }]
    }
})



const popularItemsChart = computed(() => {
    const sorted = topItems.value
    
    return {
        labels: sorted.map(i => i.name),
        datasets: [{
            label: '借用次數',
            backgroundColor: 'hsl(var(--primary))',
            data: sorted.map(i => i.count),
            borderRadius: 4,
            barThickness: 40,
            maxBarThickness: 50
        }]
    }
})

const chartOptions = computed(() => {
    const textColor = isDark.value ? '#ffffff' : 'hsl(var(--muted-foreground))' // White text in dark mode
    const gridColor = 'hsl(var(--border))' // lighter grid
    
    return {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
            legend: { 
                display: false 
            },
            tooltip: {
                backgroundColor: 'hsl(var(--popover))',
                titleColor: 'hsl(var(--popover-foreground))',
                bodyColor: 'hsl(var(--popover-foreground))',
                borderColor: 'hsl(var(--border))',
                borderWidth: 1,
                padding: 10,
                displayColors: false
            }
        },
        scales: {
            x: { 
                grid: { display: false },
                ticks: { color: textColor, font: { size: 11 } }
            },
            y: { 
                beginAtZero: true,
                grid: { 
                    color: isDark.value ? '#27272a' : '#e4e4e7', // zinc-800 : zinc-200
                    borderDash: [4, 4], // Dashed grid lines
                    drawBorder: false // Remove axis line
                },
                ticks: { stepSize: 1, color: textColor, font: { size: 11 } }
            }
        },
        elements: {
            line: {
                fill: true, // Gradient fill
            }
        }
    }
})

const doughnutOptions = computed(() => { 
    return {
        responsive: true,
        maintainAspectRatio: false,
        cutout: '75%', // Thinner donut
        layout: {
            padding: 20 // Prevent hover truncation
        },
        onHover: (event, elements) => {
             if (elements && elements.length > 0) {
                 const index = elements[0].index;
                 const dataset = inventoryDistribution.value.datasets[0];
                 const value = dataset.data[index]
                 const label = inventoryDistribution.value.labels[index]
                 const total = inventoryDistribution.value.totalStock || 1
                 const percent = Math.round((value / total) * 100) + '%'
                 hoveredInventoryItem.value = { value, label, percent }
             } else {
                 hoveredInventoryItem.value = null
             }
        },
        plugins: {
            legend: { 
                display: false 
            },
            tooltip: {
                enabled: false // Disable tooltip completely as requested
            }
        }
    }
})

// Intersection Observer for Feed Animation
const feedSection = ref(null)
const isFeedVisible = ref(false)

useIntersectionObserver(
  feedSection,
  ([{ isIntersecting }]) => {
    if (isIntersecting) {
        isFeedVisible.value = true
    }
  },
  { threshold: 0.1 } // Trigger when 10% visible
)

// Intersection Observer for Layer 2 (Popular Items & Low Stock)
const layer2Section = ref(null)
const isLayer2Visible = ref(false)

useIntersectionObserver(
  layer2Section,
  ([{ isIntersecting }]) => {
    if (isIntersecting) {
        isLayer2Visible.value = true
    }
  },
  { threshold: 0.1 }
)

</script>

<template>
  <div class="flex flex-col gap-6">
      
       <!-- Layer 1: The Pulse -->
       <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 animate-in fade-in slide-in-from-bottom-4 duration-700 fill-mode-both" style="animation-fill-mode: both;">
           <!-- Pending -->
            <div @click="showPendingModal = true" class="bg-card border border-border rounded-xl p-5 flex flex-col justify-between h-32 relative overflow-hidden group cursor-pointer hover:border-zinc-400 dark:hover:border-zinc-700 transition-colors shadow-sm">
               <div class="flex justify-between items-start">
                   <span class="text-sm font-medium text-muted-foreground">待審核申請</span>
                   <AlertCircleIcon class="w-4 h-4 text-muted-foreground" />
               </div>
               <div class="text-4xl font-bold text-foreground tracking-tight mt-2">
                   {{ Math.round(pendingCount) }}
               </div>
           </div>

           <!-- Active Loans -->
           <div @click="showActiveLoansModal = true" class="bg-card border border-border rounded-xl p-5 flex flex-col justify-between h-32 relative overflow-hidden group cursor-pointer hover:border-zinc-400 dark:hover:border-zinc-700 transition-colors shadow-sm">
               <div class="flex justify-between items-start">
                   <span class="text-sm font-medium text-muted-foreground">出借中器材</span>
                   <ClockIcon class="w-4 h-4 text-muted-foreground" />
               </div>
               <div class="text-4xl font-bold text-foreground tracking-tight mt-2">
                   {{ Math.round(activeLoansCount) }}
               </div>
           </div>

           <!-- Low Stock -->
           <div @click="showLowStockModal = true" class="bg-card border border-border rounded-xl p-5 flex flex-col justify-between h-32 relative overflow-hidden group cursor-pointer hover:border-zinc-400 dark:hover:border-zinc-700 transition-colors shadow-sm">
               <div class="flex justify-between items-start">
                   <span class="text-sm font-medium text-muted-foreground">庫存緊張</span>
                   <div v-if="lowStockCount > 0" class="flex items-center justify-center bg-red-50 dark:bg-red-500/15 rounded text-[10px] font-bold px-1.5 py-0.5 text-red-700 dark:text-red-400">
                        Alert
                   </div>
               </div>
               <div class="text-4xl font-bold text-foreground tracking-tight mt-2">
                   {{ Math.round(lowStockCount) }}
               </div>
           </div>

           <!-- Monthly Usage -->
           <div class="bg-card border border-border rounded-xl p-5 flex flex-col justify-between h-32 relative overflow-hidden group shadow-sm">
               <div class="flex justify-between items-start">
                   <span class="text-sm font-medium text-muted-foreground">本月總借用次數</span>
                   <CheckCircleIcon class="w-4 h-4 text-muted-foreground" />
               </div>
               <div class="text-4xl font-bold text-foreground tracking-tight mt-2">
                   {{ Math.round(monthlyUsage) }}
               </div>
           </div>
      </div>

      <!-- Layer 2: The Trends -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Monthly Usage Trend -->
        <div class="lg:col-span-2 bg-card border border-border rounded-xl p-6 shadow-sm">
            <div class="flex justify-between items-center mb-6">
                <div>
                    <h3 class="text-lg font-bold text-foreground">借用趨勢</h3>
                    <p class="text-sm text-muted-foreground">近 7 天器材與耗材借用狀況</p>
                </div>
                <select v-model="trendPeriod" class="text-sm border-border bg-background text-foreground rounded-md px-2 py-1 focus:ring-ring focus:border-ring">
                    <option value="7d">近 7 天</option>
                    <option value="30d">近 30 天</option>
                </select>
            </div>
            <div class="h-[300px] w-full">
                 <Line :data="borrowingTrend" :options="chartOptions" />
            </div>
        </div>

        <!-- Inventory Distribution -->
        <div class="bg-card border border-border rounded-xl p-6 shadow-sm flex flex-col">
             <div class="flex justify-between items-start mb-2">
                 <div>
                    <h3 class="text-lg font-bold text-foreground">庫存分佈</h3>
                    <p class="text-sm text-muted-foreground">器材與耗材佔比</p>
                 </div>
                 <!-- Total Count Badge Removed - Moving to Center -->
             </div>
             
             <div class="flex flex-col items-center gap-6 flex-1 pt-4">
                 <!-- Chart -->
                 <div class="h-[220px] w-[220px] relative shrink-0">
                     <Doughnut :data="inventoryDistribution" :options="doughnutOptions" />
                     
                     <!-- Center Text Overlay -->
                     <div class="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
                        <template v-if="hoveredInventoryItem">
                             <span class="text-3xl font-bold text-foreground animate-in fade-in zoom-in-95 duration-200">
                                 {{ hoveredInventoryItem.percent }}
                             </span>
                             <span class="text-xs text-muted-foreground font-medium mt-1">
                                 {{ hoveredInventoryItem.label }}
                             </span>
                        </template>
                        <template v-else>
                             <span class="text-3xl font-bold text-foreground">
                                 {{ inventory.length }}
                             </span>
                             <span class="text-xs text-muted-foreground font-medium mt-1">
                                 總品項
                             </span>
                        </template>
                     </div>
                 </div>
                 
                 <!-- Custom Legend (Bottom) -->
                 <div class="w-full grid grid-cols-2 gap-x-6 gap-y-3 pt-4 border-t border-border/50">
                     <div v-for="(label, i) in inventoryDistribution.labels" :key="label" class="flex items-center justify-between group">
                         <div class="flex items-center gap-2 min-w-0 w-full hover:bg-muted/50 rounded px-2 py-1 transition-colors">
                             <!-- Restore Legend Dot -->
                             <span class="w-2 h-2 rounded-full ring-2 ring-transparent group-hover:ring-border transition-all shrink-0" :style="{ backgroundColor: inventoryDistribution.datasets[0].backgroundColor[i] }"></span>
                             
                             <div class="flex-1 flex justify-between items-center min-w-0">
                                 <span class="text-sm font-medium text-foreground truncate mr-2">{{ label }}</span>
                                 <span class="text-sm font-bold text-muted-foreground font-mono shrink-0">
                                     {{ Math.round((inventoryDistribution.datasets[0].data[i] / (inventoryDistribution.totalStock || 1)) * 100) }}%
                                 </span>
                             </div>
                         </div>
                     </div>
                 </div>
             </div>
        </div>
    </div>       <!-- Popular Items (Bar) Replaces manual ranking list if we want, or keep both. Limit space. -->
           <!-- Let's put Popular Items as a Bar Chart in a FULL row below or replace the manual list? -->
           <!-- User plan said: 3 cards. Distribution, Popular, Trend. -->
           <!-- We currently have 3 slots in this grid. -->
           <!-- Let's adjust grid: 
                Row 1: [Distribution (1/3)] [Popular (2/3) - Bar Chart] 
                Row 2: [Trend (Full)]
                
                Actually, Distribution is best square. Trend is wide. Popular can be list or bar.
                Let's stick to:
                [ Distribution ] [ Trend ] -> As is
                Add a NEW row for [ Popular Items (Bar) ]
           -->
      <div ref="layer2Section" 
           class="grid grid-cols-1 lg:grid-cols-2 gap-6 transition-opacity duration-700" 
           :class="isLayer2Visible ? 'animate-in fade-in slide-in-from-bottom-4 fill-mode-both' : 'opacity-0'">
        <!-- Popular Items -->
        <div class="bg-card border border-border rounded-xl p-6 shadow-sm">
             <h3 class="text-lg font-bold text-foreground mb-4">熱門借用排行</h3>
             <div class="space-y-4">
                 <div v-for="(item, i) in topItems" :key="item.name" class="flex items-center gap-3">
                     <span class="w-6 h-6 flex items-center justify-center rounded-full text-xs font-bold" 
                        :class="i < 3 ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground'">
                        {{ i + 1 }}
                     </span>
                     <div class="flex-1 min-w-0">
                         <div class="flex justify-between mb-1">
                             <span class="text-sm font-medium text-foreground truncate">{{ item.name }}</span>
                             <span class="text-xs font-bold text-foreground">{{ item.count }} 次</span>
                         </div>
                         <div class="w-full bg-muted rounded-full h-1.5 overflow-hidden">
                             <div class="bg-primary/80 h-1.5 rounded-full transition-all duration-1000 ease-out delay-300" 
                                  :style="{ width: isLayer2Visible ? `${(item.count / (topItems[0]?.count || 1)) * 100}%` : '0%' }"></div>
                         </div>
                     </div>
                 </div>
                 <div v-if="topItems.length === 0" class="text-center py-8 text-muted-foreground">
                    尚無熱門資料
                 </div>
             </div>
        </div>

        <!-- Low Stock Alert -->
        <div class="bg-card border border-border rounded-xl p-6 shadow-sm flex flex-col">
             <div class="flex justify-between items-center mb-4">
                <h3 class="text-lg font-bold text-foreground">低庫存警示</h3>
                <RouterLink to="/admin/dashboard" class="text-xs font-medium text-primary hover:underline">查看全部</RouterLink>
             </div>
             
             <div class="space-y-3 flex-1 overflow-y-auto max-h-[300px] pr-2">
                 <div v-for="item in lowStockItems" :key="item.id" class="flex items-center justify-between p-3 rounded-lg bg-muted/50 border border-border">
                     <div class="flex items-center gap-3">
                         <div class="w-2 h-2 rounded-full bg-red-500"></div>
                         <div>
                             <div class="text-sm font-medium text-foreground">{{ item.name }}</div>
                             <div class="text-xs text-muted-foreground">ID: {{ item.custom_id || 'N/A' }}</div>
                         </div>
                     </div>
                     <div class="text-right">
                         <div class="text-sm font-bold text-red-600 dark:text-red-400">{{ item.total_stock }}</div>
                         <div class="text-[10px] text-muted-foreground">安全: {{ item.safety_stock }}</div>
                     </div>
                 </div>
                 <div v-if="lowStockItems.length === 0" class="text-center py-12 flex flex-col items-center justify-center text-muted-foreground h-full">
                    <CheckCircleIcon class="w-8 h-8 mb-2 text-green-500" />
                    <span>庫存充足</span>
                 </div>
             </div>
        </div>
    </div>
      <!-- Layer 3: The Feed -->
      <div ref="feedSection" 
           class="bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-xl overflow-hidden flex flex-col transition-opacity duration-700" 
           :class="isFeedVisible ? 'animate-in fade-in slide-in-from-bottom-4 fill-mode-both' : 'opacity-0'">
          <div class="p-6 border-b border-zinc-100 dark:border-zinc-800 flex justify-between items-center">
              <h3 class="text-sm font-medium text-zinc-500 dark:text-zinc-400">即時動態</h3>
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
                          class="border-b border-zinc-50 dark:border-zinc-800 hover:bg-zinc-50 dark:hover:bg-zinc-800/50 transition-colors group cursor-pointer">
                          <td class="px-6 py-4 w-12">
                              <div v-if="item.priority === 'critical'" class="w-2 h-2 rounded-full bg-red-500"></div>
                              <div v-else-if="item.priority === 'high'" class="w-2 h-2 rounded-full bg-orange-500"></div>
                              <div v-else class="w-2 h-2 rounded-full bg-zinc-300 dark:bg-zinc-600"></div>
                          </td>
                          <td class="px-6 py-4">
                              <span class="text-sm font-bold text-zinc-900 dark:text-zinc-100 block mb-0.5">{{ item.title }}</span>
                              <span class="text-xs text-zinc-500 dark:text-zinc-400">{{ item.desc }}</span>
                          </td>
                          <td class="px-6 py-4 text-right">
                               <span class="text-xs font-mono text-zinc-400 px-2 py-1 rounded bg-zinc-100 dark:bg-zinc-800 border border-zinc-200 dark:border-zinc-700">{{ format(new Date(item.date), 'yyyy/MM/dd') }}</span>
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
                                <span class="text-sm font-bold text-red-600 dark:text-red-400 px-2 py-0.5 bg-red-50 dark:bg-red-500/15 rounded">{{ item.total_stock }}</span>
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
