<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { useCartStore } from '../stores/cart'
import { PlusIcon } from '@heroicons/vue/20/solid'
import { CalendarDaysIcon } from '@heroicons/vue/24/outline'
import ScheduleModal from '../components/ScheduleModal.vue'
import Skeleton from '@/components/ui/skeleton/Skeleton.vue'

const items = ref([])
const bookings = ref([])
const loading = ref(true)
const cart = useCartStore()

// Modal State
const showScheduleModal = ref(false)
const selectedRoomName = ref('')
const selectedBookings = ref([])

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

// Helper to filter bookings for a specific room (Shared Logic)
function filterBookingsForRoom(item, limit = null) {
    if (!bookings.value.length) return []

    const conflictMap = {
        '會議室A': ['會議室A', '會議室A+B'],
        '會議室B': ['會議室B', '會議室A+B'],
        '會議室A+B': ['會議室A', '會議室B', '會議室A+B']
    }
    
    let myKey = ''
    if (item.name.includes('A+B')) myKey = '會議室A+B'
    else if (item.name.includes('A')) myKey = '會議室A'
    else if (item.name.includes('B')) myKey = '會議室B'
    
    if (!myKey) return []

    const relevantKeywords = conflictMap[myKey]

    const filtered = bookings.value.filter(booking => {
        // Must have valid time slots (Exclude equipment orders)
        if (!booking.start_time || !booking.end_time) return false

        return booking.order_items.some(oi => {
             if (oi.item_name_snapshot.includes('A+B')) return relevantKeywords.includes('會議室A+B')
             if (oi.item_name_snapshot.includes('A') && !oi.item_name_snapshot.includes('B')) return relevantKeywords.includes('會議室A')
             if (oi.item_name_snapshot.includes('B') && !oi.item_name_snapshot.includes('A')) return relevantKeywords.includes('會議室B')
             return false
        })
    })
    
    return limit ? filtered.slice(0, limit) : filtered
}

// For Card Display (Limited)
function getRoomBookings(item) {
    return filterBookingsForRoom(item, 5)
}

function openSchedule(item) {
    selectedRoomName.value = item.name
    selectedBookings.value = filterBookingsForRoom(item) // No limit
    showScheduleModal.value = true
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
      <h1 class="text-3xl font-bold text-foreground mb-2">空間預約</h1>
      <p class="text-muted-foreground">選擇您需要的會議室。</p>
    </div>

    <!-- Loading State (Skeleton) -->
    <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <div v-for="n in 3" :key="n" class="bg-card rounded-xl shadow-sm border border-border p-6 flex flex-col justify-between h-[220px]">
        <div>
           <div class="flex justify-between items-start mb-4">
             <Skeleton class="h-5 w-20 bg-muted" /> 
             <Skeleton class="h-5 w-16 bg-muted" />
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
      <div v-for="item in items" :key="item.id" class="group bg-card rounded-lg border border-border p-5 flex flex-col justify-between hover:border-input transition-colors h-[480px]">
        
        <!-- Info -->
        <div class="mb-4">
          <div class="flex justify-between items-start mb-3">
             <!-- Category Tag Removed -->
          </div>
          <h3 class="text-lg font-bold text-foreground mb-1 leading-tight">{{ item.name }}</h3>
          <p class="text-sm text-muted-foreground mb-4 h-10">
             {{ item.name.includes('A+B') ? '可投影。適合大型會議或培訓。' : (item.name.includes('A') ? '可投影。適合會議、討論。' : '無法投影。適合小組討論或面試。') }}
          </p>
          
           <!-- Booking Schedule -->
           <div class="mt-6 flex-1 flex flex-col h-[180px] overflow-hidden">
              <h4 class="text-[10px] font-bold text-muted-foreground uppercase tracking-widest mb-3 flex items-center gap-1.5">
                 <CalendarDaysIcon class="w-3 h-3" />
                 近期預約
              </h4>
              
              <div v-if="getRoomBookings(item).length === 0" class="flex-1 flex items-center justify-center text-xs text-zinc-400 font-medium">
                 目前無預約
              </div>

              <div v-else class="flex-1 overflow-y-auto pr-1 custom-scrollbar space-y-3">
                 <div v-for="booking in getRoomBookings(item)" :key="booking.id" class="flex justify-between items-start group/item">
                    <div>
                       <div class="text-sm font-medium text-foreground leading-none mb-1">{{ booking.applicant_name }}</div>
                       <div class="text-[10px] text-muted-foreground font-mono">{{ booking.start_date }}</div>
                    </div>
                    
                     <div class="text-right">
                        <div class="font-mono text-xs text-muted-foreground font-medium">
                            {{ booking.start_time }}-{{ booking.end_time }}
                        </div>
                         <span v-if="booking.order_items.some(oi => oi.item_name_snapshot.includes('A+B')) && !item.name.includes('A+B')" class="text-[9px] text-orange-600 bg-orange-50 px-1 py-0.5 rounded mt-0.5 inline-block">
                          ( A+B )
                       </span>
                    </div>
                 </div>
              </div>
           </div>

        </div>

        <!-- Action -->
        <div class="mt-auto flex flex-col gap-3">
            <button 
              @click="openSchedule(item)"
              class="w-full flex items-center justify-center gap-2 bg-card text-foreground border border-border py-2.5 rounded-md hover:bg-muted hover:text-foreground transition-all text-sm font-medium"
            >
              <CalendarDaysIcon class="w-4 h-4" />
              查看一週檔期
            </button>
            
            <button 
              @click="cart.addItem(item)"
              class="w-full flex items-center justify-center gap-2 bg-primary text-primary-foreground border border-transparent py-2.5 rounded-md hover:bg-primary/90 transition-all text-sm font-medium opacity-0 group-hover:opacity-100"
            >
              <PlusIcon class="w-4 h-4" />
              加入預約清單
            </button>
        </div>
      </div>
    </div>

    <!-- Empty State -->
    <div v-if="!loading && items.length === 0" class="text-center py-12 bg-zinc-50 rounded-lg border border-dashed border-zinc-200">
        <p class="text-zinc-500">目前沒有開放的空間。</p>
    </div>

    <!-- Schedule Modal -->
    <ScheduleModal 
      :is-open="showScheduleModal"
      :room-name="selectedRoomName"
      :bookings="selectedBookings"
      @close="showScheduleModal = false"
    />

  </div>
</template>
