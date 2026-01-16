<script setup>
import { ref, computed, watch, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { useCartStore } from '../stores/cart'
import { useAuthStore } from '../stores/auth'
import { supabase } from '../lib/supabase'
import { TrashIcon, CheckCircleIcon, ClipboardDocumentListIcon, PlusIcon, MinusIcon } from '@heroicons/vue/24/outline'
import { CalendarIcon } from 'lucide-vue-next'
import { format } from 'date-fns'
import { parseDate, today, getLocalTimeZone } from '@internationalized/date'

import { Button } from '@/components/ui/button'
import { Calendar } from '@/components/ui/calendar'
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { cn } from '@/lib/utils'

const cart = useCartStore()
const auth = useAuthStore()
const router = useRouter()
const loading = ref(false)
const success = ref(false)
const errorMsg = ref('')

// --- Split Forms ---
const commonForm = reactive({
  applicant_name: '',
  department: '', // Default to empty string if not provided
  purpose: '',
})

// Space Specific
const spaceForm = reactive({
  date: '',
  start_time: '',
  end_time: ''
})
const spaceDateValue = ref()

// Equipment Specific
const equipForm = reactive({
  start_date: '',
  end_date: ''
})
const equipStartDateValue = ref()
const equipEndDateValue = ref()

// --- Date Helpers ---
const todayDate = today(getLocalTimeZone())

watch(spaceDateValue, (v) => spaceForm.date = v ? v.toString() : '')
watch(equipStartDateValue, (v) => equipForm.start_date = v ? v.toString() : '')
watch(equipEndDateValue, (v) => equipForm.end_date = v ? v.toString() : '')

// Auto-fill
if (auth.user && auth.user.name) {
    commonForm.applicant_name = auth.user.name
}

// --- Cart Categorization ---
const spaceItems = computed(() => cart.items.filter(i => i.category === '空間'))
const equipItems = computed(() => cart.items.filter(i => i.category !== '空間' && i.type !== 'CONSUMABLE'))
const consumableItems = computed(() => cart.items.filter(i => i.type === 'CONSUMABLE'))

const hasSpace = computed(() => spaceItems.value.length > 0)
const hasEquip = computed(() => equipItems.value.length > 0)
const hasConsumable = computed(() => consumableItems.value.length > 0)

const timeOptions = [
  '08:00', '09:00', '10:00', '11:00', '12:00', 
  '13:00', '14:00', '15:00', '16:00', '17:00', 
  '18:00', '19:00'
]

async function submitOrder() {
  if (cart.items.length === 0) return
  errorMsg.value = ''

  // 1. Auth Check
  if (!auth.isAuthenticated) {
      if (confirm('請先登入才能送出申請')) router.push('/')
      return
  }

  // 2. Validation
  // Common
  if (!commonForm.applicant_name || !commonForm.purpose) {
      errorMsg.value = '請填寫申請人姓名與用途'
      return
  }

  // Space Validation
  if (hasSpace.value) {
      if (!spaceForm.date || !spaceForm.start_time || !spaceForm.end_time) {
          errorMsg.value = '[空間預約] 請完整填寫日期與時段'
          return
      }
      if (spaceForm.start_time >= spaceForm.end_time) {
          errorMsg.value = '[空間預約] 結束時間必須晚於開始時間'
          return
      }
  }

  // Equipment Validation
  if (hasEquip.value) {
      if (!equipForm.start_date || !equipForm.end_date) {
          errorMsg.value = '[器材借用] 請填寫借用與歸還日期'
          return
      }
      if (equipForm.start_date > equipForm.end_date) {
          errorMsg.value = '[器材借用] 歸還日期不能早於開始日期'
          return
      }
  }

  loading.value = true

  try {
      const ordersToCreate = []

      // Prepare Space Order
      if (hasSpace.value) {
          
          // CONFLICT CHECK
          for (const item of spaceItems.value) {
             await checkSpaceConflict(item, spaceForm.date, spaceForm.start_time, spaceForm.end_time)
          }

          ordersToCreate.push({
              type: 'SPACE', // Tag for clarity
              items: spaceItems.value,
              data: {
                  ...commonForm,
                  start_date: spaceForm.date,
                  end_date: spaceForm.date, // Same day for space
                  start_time: spaceForm.start_time,
                  end_time: spaceForm.end_time,
                  status: 'APPROVED' // Auto-approved for Space
              }
          })
      }

      // Prepare Equipment Order
      if (hasEquip.value) {
          ordersToCreate.push({
              type: 'loan',
              items: equipItems.value,
              data: {
                  ...commonForm,
                  start_date: equipForm.start_date,
                  end_date: equipForm.end_date,
                  status: 'PENDING'
              }
          })
      }

      // Prepare Consumable Order
      if (hasConsumable.value) {
          const todayStr = todayDate.toString()
          ordersToCreate.push({
              type: 'CONSUMABLE',
              items: consumableItems.value,
              data: {
                  ...commonForm,
                  start_date: todayStr,
                  end_date: todayStr,
                  status: 'COMPLETED' // Auto-approved
              }
          })
      }

      // Submitting all orders
      for (const orderRequest of ordersToCreate) {
          // 1. Insert Order
          const { data: orderData, error: orderError } = await supabase
              .from('orders')
              .insert(orderRequest.data)
              .select()
              .single()

          if (orderError) throw orderError

          // 2. Insert Items
          const orderItems = orderRequest.items.map(item => ({
              order_id: orderData.id,
              item_id: item.id,
              item_name_snapshot: item.name,
              quantity: item.quantity
          }))

          const { error: itemsError } = await supabase
              .from('order_items')
              .insert(orderItems)
          
          if (itemsError) throw itemsError

          // 3. Decrement Stock (Only for Consumables)
          if (orderRequest.type === 'CONSUMABLE') {
               for (const item of orderRequest.items) {
                   await supabase.rpc('decrement_stock', { 
                       item_id: item.id, 
                       amount: item.quantity 
                   })
               }
          }
      }

      success.value = true
      cart.clearCart()

  } catch (e) {
      console.error(e)
      errorMsg.value = '提交失敗: ' + e.message
  } finally {
      loading.value = false
  }
}

// Conflict Checker Helper
async function checkSpaceConflict(spaceItem, date, startTime, endTime) {
    // 1. Fetch relevant orders
    const { data: orders, error } = await supabase
        .from('orders')
        .select(`
            id,
            start_time,
            end_time,
            status,
            order_items (
                item_name_snapshot
            )
        `)
        .eq('start_date', date) // Same Day
        .neq('status', 'REJECTED')
        .neq('status', 'CANCELLED')
        .neq('status', 'RETURNED') // Assuming logic: Returned means it WAS used, but checking for future conflicts usually implies 'ACTIVE' bookings.
                                   // Actually, if it's 'RETURNED', the slot is free NOW, but we are booking a specific time slot.
                                   // If history shows 'RETURNED' for 10:00-12:00, that slot WAS taken.
                                   // But we are usually preventing future overlaps.
                                   // Safest to exclude REJECTED/CANCELLED. 
                                   // Better: Only check PENDING / APPROVED.

    if (error) throw error

    // Filter for Active Status only
    const activeOrders = orders.filter(o => ['PENDING', 'APPROVED'].includes(o.status))

    // 2. Define Conflict Map
    const conflictMap = {
        '會議室A': ['會議室A', '會議室A+B'],
        '會議室B': ['會議室B', '會議室A+B'],
        '會議室A+B': ['會議室A', '會議室B', '會議室A+B']
    }

    // Target Room Name (normalize)
    // Assume input item name contains key keywords
    let targetKey = ''
    if (spaceItem.name.includes('A+B')) targetKey = '會議室A+B'
    else if (spaceItem.name.includes('A')) targetKey = '會議室A'
    else if (spaceItem.name.includes('B')) targetKey = '會議室B'

    if (!targetKey) return // No conflict rules for other spaces

    const conflictingRooms = conflictMap[targetKey]

    // 3. Iterate and Check
    for (const order of activeOrders) {
        // Time Overlap Check: (StartA < EndB) and (EndA > StartB)
        // Note: Time format is "HH:mm" (string comparison works for 24h)
        if (startTime < order.end_time && endTime > order.start_time) {
            
            // Check Room Name in this order
            // An order might have multiple items, check if ANY is a conflicting room
            const hasConflictingRoom = order.order_items.some(oi => {
                if (oi.item_name_snapshot.includes('A+B') && conflictingRooms.includes('會議室A+B')) return true
                if (oi.item_name_snapshot.includes('A') && !oi.item_name_snapshot.includes('B') && conflictingRooms.includes('會議室A')) return true
                if (oi.item_name_snapshot.includes('B') && !oi.item_name_snapshot.includes('A') && conflictingRooms.includes('會議室B')) return true
                return false
            })

            if (hasConflictingRoom) {
                throw new Error(`該時段與現有預約衝突 (${order.start_time}-${order.end_time})`)
            }
        }
    }
}
</script>

<template>
  <div class="max-w-6xl mx-auto"> <!-- Increased from max-w-3xl to max-w-6xl -->
    
    <!-- Empty Cart -->
    <div v-if="cart.items.length === 0 && !success" class="text-center py-16 bg-white rounded-lg border border-zinc-200 border-dashed">
      <div class="text-zinc-300 mb-4">
        <!-- Clipboard Icon -->
        <ClipboardDocumentListIcon class="w-16 h-16 mx-auto" />
      </div>
      <h2 class="text-xl font-bold text-zinc-900 mb-2">借用清單是空的</h2>
      <p class="text-zinc-500 mb-6 font-medium">還沒加入任何項目喔！</p>
      <button @click="router.push('/')" class="bg-zinc-900 text-white px-6 py-2.5 rounded-md hover:bg-zinc-800 transition text-sm font-medium">去逛逛器材</button>
    </div>

    <!-- Success Message -->
    <div v-else-if="success" class="bg-white p-12 rounded-lg border border-zinc-200 text-center shadow-sm">
      <div class="w-16 h-16 bg-zinc-50 rounded-full flex items-center justify-center mx-auto mb-6 border border-zinc-100">
         <CheckCircleIcon class="w-8 h-8 text-zinc-900" />
      </div>
      <h2 class="text-2xl font-bold text-zinc-900 mb-2">{{ isOnlyConsumables ? '領用成功！' : '預約申請已送出！' }}</h2>
      <p class="text-zinc-500 mb-8">{{ isOnlyConsumables ? '請至相關櫃位領取耗材。' : '管理員將會審核您的申請。' }}</p>
      <button @click="router.push('/equipment')" class="bg-zinc-900 text-white px-6 py-2.5 rounded-md hover:bg-zinc-800 transition text-sm font-bold">返回首頁</button>
    </div>

    <!-- Checkout Form -->
    <div v-else class="grid grid-cols-1 lg:grid-cols-5 gap-8">
      
      <!-- Cart Items List (Left) -->
      <div class="lg:col-span-3 space-y-4">
        <h2 class="text-lg font-bold text-zinc-900 flex items-center gap-3">
          借用內容 
          <span class="bg-zinc-100 text-zinc-600 text-xs font-bold px-2 py-0.5 rounded-full border border-zinc-200">{{ cart.totalItems }}</span>
        </h2>
        
       <div class="bg-white rounded-lg border border-zinc-200 overflow-hidden divide-y divide-zinc-100">
          <div v-for="item in cart.items" :key="item.id" class="p-5 flex items-center gap-4">
             <!-- Info -->
             <div class="flex-1 flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-4">
               <div class="flex items-center gap-2 mr-auto">
                 <h3 class="font-bold text-zinc-900 text-base">{{ item.name }}</h3>
                 <span class="text-[10px] text-zinc-500 font-medium bg-zinc-100 px-1.5 py-0.5 rounded border border-zinc-200 shrink-0">{{ item.category }}</span>
               </div>
               
               <!-- Quantity Control -->
               <div class="flex items-center w-fit border border-zinc-200 rounded-md bg-white shrink-0">
                  <button 
                      @click="cart.updateQuantity(item.id, item.quantity - 1)"
                      :disabled="item.quantity <= 1"
                      class="p-1 px-2 text-zinc-500 hover:bg-zinc-50 hover:text-zinc-900 disabled:opacity-30 disabled:hover:bg-transparent transition-colors"
                  >
                      <MinusIcon class="w-3 h-3" />
                  </button>
                  <span class="text-xs font-bold font-mono px-1 w-6 text-center text-zinc-900">{{ item.quantity }}</span>
                  <button 
                      @click="cart.updateQuantity(item.id, item.quantity + 1)"
                      :disabled="item.quantity >= item.total_stock"
                      class="p-1 px-2 text-zinc-500 hover:bg-zinc-50 hover:text-zinc-900 disabled:opacity-30 disabled:hover:bg-transparent transition-colors"
                  >
                      <PlusIcon class="w-3 h-3" />
                  </button>
               </div>
             </div>

             <!-- Remove -->
             <button @click="cart.removeItem(item.id)" class="text-zinc-400 hover:text-red-500 hover:bg-red-50 p-2 rounded-full transition-colors flex items-center justify-center w-8 h-8 shrink-0">
               <TrashIcon class="w-4 h-4" />
             </button>
          </div>
        </div>
      </div>

      <!-- Applicant Form (Right) -->
      <div class="lg:col-span-2">
        <div class="bg-white p-6 rounded-lg border border-zinc-200 sticky top-24 shadow-sm space-y-6">
          
          <!-- Common Info -->
          <div>
            <h2 class="text-base font-bold text-zinc-900 mb-4 pb-2 border-b border-zinc-100">基本資料</h2>
            <div class="space-y-4">
               <div>
                  <label class="block text-xs font-bold text-zinc-500 mb-1.5 uppercase tracking-wider">姓名 *</label>
                  <input v-model="commonForm.applicant_name" type="text" class="w-full border-zinc-200 rounded-md shadow-sm focus:border-zinc-900 focus:ring-zinc-900 p-2.5 border text-sm transition-colors" placeholder="請輸入全名">
               </div>

               <div>
                  <label class="block text-xs font-bold text-zinc-500 mb-1.5 uppercase tracking-wider">用途 *</label>
                  <textarea v-model="commonForm.purpose" rows="2" class="w-full border-zinc-200 rounded-md shadow-sm focus:border-zinc-900 focus:ring-zinc-900 p-2.5 border text-sm transition-colors" placeholder="請簡述使用目的"></textarea>
               </div>
            </div>
          </div>

          <!-- Space Section -->
          <div v-if="hasSpace" class="bg-white p-5 rounded-lg border border-zinc-200">
             <h3 class="text-sm font-bold text-zinc-900 mb-4 flex items-center gap-2">
                <span class="w-1.5 h-1.5 rounded-full bg-blue-500"></span>
                空間預約資訊
             </h3>
             <div class="space-y-4">
                <div>
                   <label class="block text-xs font-bold text-zinc-500 mb-1.5 uppercase">預約日期 *</label>
                   <Popover>
                      <PopoverTrigger as-child>
                        <Button variant="outline" :class="cn('w-full justify-start text-left font-normal bg-white border-zinc-200 hover:bg-zinc-50', !spaceDateValue && 'text-muted-foreground')">
                          <CalendarIcon class="mr-2 h-4 w-4" />
                          {{ spaceDateValue ? spaceDateValue.toString() : "選擇日期" }}
                        </Button>
                      </PopoverTrigger>
                      <PopoverContent class="w-auto p-0">
                        <Calendar v-model="spaceDateValue" initial-focus :min-value="todayDate" />
                      </PopoverContent>
                   </Popover>
                </div>
                <div class="grid grid-cols-2 gap-2">
                   <div>
                      <label class="block text-[10px] font-bold text-zinc-500 mb-1 uppercase">開始時間</label>
                      <Select v-model="spaceForm.start_time">
                        <SelectTrigger class="bg-white border-zinc-200 hover:bg-zinc-50"><SelectValue placeholder="選擇" /></SelectTrigger>
                        <SelectContent>
                          <SelectItem v-for="t in timeOptions" :key="t" :value="t">{{ t }}</SelectItem>
                        </SelectContent>
                      </Select>
                   </div>
                   <div>
                      <label class="block text-[10px] font-bold text-zinc-500 mb-1 uppercase">結束時間</label>
                      <Select v-model="spaceForm.end_time">
                        <SelectTrigger class="bg-white border-zinc-200 hover:bg-zinc-50"><SelectValue placeholder="選擇" /></SelectTrigger>
                        <SelectContent>
                          <SelectItem v-for="t in timeOptions" :key="t" :value="t">{{ t }}</SelectItem>
                        </SelectContent>
                      </Select>
                   </div>
                </div>
             </div>
          </div>

          <!-- Equipment Section -->
          <div v-if="hasEquip" class="bg-white p-5 rounded-lg border border-zinc-200">
             <h3 class="text-sm font-bold text-zinc-900 mb-4 flex items-center gap-2">
                <span class="w-1.5 h-1.5 rounded-full bg-zinc-900"></span>
                器材借用資訊
             </h3>
             <div class="grid grid-cols-2 gap-3">
               <div>
                 <label class="block text-xs font-bold text-zinc-500 mb-1.5 uppercase">借用日期 *</label>
                 <Popover>
                   <PopoverTrigger as-child>
                     <Button variant="outline" :class="cn('w-full justify-start text-left font-normal bg-white border-zinc-200 hover:bg-zinc-50', !equipStartDateValue && 'text-muted-foreground')">
                       <CalendarIcon class="mr-2 h-4 w-4" />
                       {{ equipStartDateValue ? equipStartDateValue.toString() : "選擇日期" }}
                     </Button>
                   </PopoverTrigger>
                   <PopoverContent class="w-auto p-0">
                     <Calendar v-model="equipStartDateValue" initial-focus :min-value="todayDate" />
                   </PopoverContent>
                 </Popover>
               </div>
               <div>
                 <label class="block text-xs font-bold text-zinc-500 mb-1.5 uppercase">歸還日期 *</label>
                 <Popover>
                   <PopoverTrigger as-child>
                     <Button variant="outline" :class="cn('w-full justify-start text-left font-normal bg-white border-zinc-200 hover:bg-zinc-50', !equipEndDateValue && 'text-muted-foreground')">
                       <CalendarIcon class="mr-2 h-4 w-4" />
                       {{ equipEndDateValue ? equipEndDateValue.toString() : "選擇日期" }}
                     </Button>
                   </PopoverTrigger>
                   <PopoverContent class="w-auto p-0">
                     <Calendar v-model="equipEndDateValue" initial-focus :min-value="equipStartDateValue || todayDate" />
                   </PopoverContent>
                 </Popover>
               </div>
             </div>
          </div>

          <!-- Consumables Notice -->
          <div v-if="hasConsumable" class="bg-white p-4 rounded-r-lg border-l-4 border-orange-500 shadow-sm flex gap-3 items-start">
             <div class="bg-orange-50 p-1.5 rounded-full shrink-0">
                <CheckCircleIcon class="w-4 h-4 text-orange-600" />
             </div>
             <div class="text-sm text-zinc-600">
                <span class="font-bold text-zinc-900 block mb-0.5">包含耗材項目</span>
                耗材將於送出申請後直接視為「已領取」。
             </div>
          </div>

          <!-- Submission -->
          <div class="pt-4 border-t border-zinc-100">
             <div v-if="errorMsg" class="text-red-600 text-sm bg-red-50 p-3 rounded border border-red-100 flex items-center gap-2 mb-4">
               <span class="font-bold">!</span> {{ errorMsg }}
             </div>

             <button 
               @click="submitOrder" 
               :disabled="loading"
               class="w-full bg-zinc-900 text-white py-3 rounded-md font-bold hover:bg-zinc-800 disabled:opacity-50 transition-all text-sm shadow-sm"
             >
               {{ loading ? '處理中...' : '確認送出申請' }}
             </button>
          </div>

        </div>
      </div>

    </div>
  </div>
</template>
