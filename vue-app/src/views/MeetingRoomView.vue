<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { useCartStore } from '../stores/cart'
import { PlusIcon, UserGroupIcon } from '@heroicons/vue/20/solid'

const items = ref([])
const bookings = ref([])
const loading = ref(true)
const cart = useCartStore()

async function fetchRooms() {
  loading.value = true
  // Fetch items where category is '空間' (Space)
  const { data, error } = await supabase
    .from('items')
    .select('*')
    .eq('category', '空間')
    .eq('is_active', true)
    
  if (error) {
    console.error('Error fetching rooms:', error)
  } else {
    items.value = data
  }
  loading.value = false
}

async function fetchBookings() {
   const today = new Date().toISOString().split('T')[0]
   const { data, error } = await supabase
        .from('orders')
        .select(`
            id,
            start_date,
            start_time,
            end_time,
            applicant_name,
            status,
            order_items (
                item_name_snapshot
            )
        `)
        .gte('start_date', today)
        .in('status', ['APPROVED', 'PENDING'])
        .order('start_date', { ascending: true })
        .order('start_time', { ascending: true })

    if (error) console.error(error)
    else bookings.value = data
}

function getRoomBookings(item) {
    if (!bookings.value.length) return []

    const conflictMap = {
        '會議室A': ['會議室A', '會議室A+B'],
        '會議室B': ['會議室B', '會議室A+B'],
        '會議室A+B': ['會議室A', '會議室B', '會議室A+B']
    }
    
    // Determine my key
    let myKey = ''
    if (item.name.includes('A+B')) myKey = '會議室A+B'
    else if (item.name.includes('A')) myKey = '會議室A'
    else if (item.name.includes('B')) myKey = '會議室B'
    
    if (!myKey) return []

    const relevantKeywords = conflictMap[myKey]

    return bookings.value.filter(booking => {
        // Check if ANY item in this booking matches relevant keywords
        return booking.order_items.some(oi => {
             // Simply check inclusion
             if (oi.item_name_snapshot.includes('A+B')) return relevantKeywords.includes('會議室A+B')
             if (oi.item_name_snapshot.includes('A') && !oi.item_name_snapshot.includes('B')) return relevantKeywords.includes('會議室A')
             if (oi.item_name_snapshot.includes('B') && !oi.item_name_snapshot.includes('A')) return relevantKeywords.includes('會議室B')
             return false
        })
    }).slice(0, 5) // Limit to 5
}

onMounted(() => {
  fetchRooms()
  fetchBookings()
})
</script>

<template>
  <div>
    <!-- Header -->
    <div class="mb-8 text-center sm:text-left">
      <h1 class="text-3xl font-bold text-gray-900 mb-2">空間預約</h1>
      <p class="text-gray-500">選擇您需要的會議室。</p>
    </div>

    <!-- Loading State (Skeleton) -->
    <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <div v-for="n in 3" :key="n" class="bg-white rounded-xl shadow-sm border border-gray-100 p-6 flex flex-col justify-between h-[220px]">
        <div>
           <div class="flex justify-between items-start mb-4">
             <Skeleton class="h-5 w-20 bg-zinc-100" /> 
             <Skeleton class="h-5 w-16 bg-zinc-100" />
           </div>
           <Skeleton class="h-7 w-3/4 mb-3" /> <!-- Larger Title for Rooms -->
           <Skeleton class="h-4 w-full mb-1" />
           <Skeleton class="h-4 w-2/3" />
        </div>
        <Skeleton class="h-10 w-full mt-4" />
      </div>
    </div>

    <!-- Grid -->
    <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="item in items" :key="item.id" class="group bg-white rounded-lg border border-zinc-200 p-5 flex flex-col justify-between hover:border-zinc-300 transition-colors h-[420px]">
        
        <!-- Info -->
        <div class="mb-4">
          <div class="flex justify-between items-start mb-3">
             <!-- Category Tag Removed -->
             <div class="text-[10px] font-medium text-zinc-500 border border-zinc-200 px-2 py-0.5 rounded bg-zinc-50 ml-auto">
                可預約數: {{ item.total_stock }}
             </div>
          </div>
          <h3 class="text-lg font-bold text-zinc-900 mb-1 leading-tight">{{ item.name }}</h3>
          <p class="text-sm text-zinc-500 mb-4 h-10">
             {{ item.name.includes('A+B') ? '可投影。適合大型會議或培訓。' : (item.name.includes('A') ? '可投影。適合會議、討論。' : '無法投影。適合小組討論或面試。') }}
          </p>
          
           <!-- Booking Schedule -->
           <div class="bg-zinc-50 rounded-md border border-zinc-100 p-3 h-[180px] overflow-hidden flex flex-col">
              <h4 class="text-xs font-bold text-zinc-400 uppercase tracking-wider mb-2 flex items-center gap-1">
                 📅 近期預約
              </h4>
              
              <div v-if="getRoomBookings(item).length === 0" class="flex-1 flex items-center justify-center text-xs text-zinc-400">
                 目前無預約
              </div>

              <div v-else class="space-y-2 overflow-y-auto pr-1 custom-scrollbar">
                 <div v-for="booking in getRoomBookings(item)" :key="booking.id" class="text-xs border-b border-zinc-200/50 last:border-0 pb-1.5 last:pb-0">
                    <div class="flex justify-between items-center text-zinc-900 font-medium mb-0.5">
                       <span>{{ booking.applicant_name }}</span>
                       <span class="font-mono bg-white px-1 rounded border border-zinc-100 text-[10px]">{{ booking.start_time }}-{{ booking.end_time }}</span>
                    </div>
                    <div class="text-zinc-500 text-[10px] flex justify-between">
                       <span>{{ booking.start_date }}</span>
                       <span v-if="booking.order_items.some(oi => oi.item_name_snapshot.includes('A+B')) && !item.name.includes('A+B')" class="text-orange-500 bg-orange-50 px-1 rounded">
                          ( A+B )
                       </span>
                    </div>
                 </div>
              </div>
           </div>

        </div>

        <!-- Action -->
        <button 
          @click="cart.addItem(item)"
          class="w-full mt-auto flex items-center justify-center gap-2 bg-zinc-900 text-white border border-transparent py-2 rounded-md hover:bg-zinc-800 transition-all text-sm font-medium opacity-0 group-hover:opacity-100"
        >
          <PlusIcon class="w-4 h-4" />
          加入預約清單
        </button>
      </div>
    </div>

    <!-- Empty State -->
    <div v-if="!loading && items.length === 0" class="text-center py-12 bg-zinc-50 rounded-lg border border-dashed border-zinc-200">
        <p class="text-zinc-500">目前沒有開放的空間。</p>
    </div>

  </div>
</template>
