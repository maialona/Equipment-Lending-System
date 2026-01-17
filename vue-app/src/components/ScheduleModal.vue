<script setup>
import { computed } from 'vue'
import {
  TransitionRoot,
  TransitionChild,
  Dialog,
  DialogPanel,
  DialogTitle,
} from '@headlessui/vue'
import { XMarkIcon } from '@heroicons/vue/24/outline'

const props = defineProps({
  isOpen: Boolean,
  roomName: String,
  bookings: Array // Array of order objects
})

const emit = defineEmits(['close'])

const today = new Date()
const next7Days = computed(() => {
    const days = []
    for (let i = 0; i < 7; i++) {
        const d = new Date(today)
        d.setDate(today.getDate() + i)
        const dateStr = d.toISOString().split('T')[0]
        days.push({
            date: dateStr,
            label: `${d.getMonth() + 1}/${d.getDate()} (${['日','一','二','三','四','五','六'][d.getDay()]})`
        })
    }
    return days
})

// Helper to convert time "08:00" to percentage (0% = 08:00, 100% = 19:00)
// Range: 08:00 - 19:00 (11 hours)
function getPosition(timeStr) {
    const [h, m] = timeStr.split(':').map(Number)
    const minutes = (h - 8) * 60 + m
    const totalMinutes = 11 * 60
    return Math.max(0, Math.min(100, (minutes / totalMinutes) * 100))
}

function getWidth(startStr, endStr) {
    const start = getPosition(startStr)
    const end = getPosition(endStr)
    return Math.max(1, end - start) // Min 1% width
}
</script>

<template>
  <TransitionRoot appear :show="isOpen" as="template">
    <Dialog as="div" @close="emit('close')" class="relative z-[60]">
      <TransitionChild
        as="template"
        enter="duration-300 ease-out"
        enter-from="opacity-0"
        enter-to="opacity-100"
        leave="duration-200 ease-in"
        leave-from="opacity-100"
        leave-to="opacity-0"
      >
        <div class="fixed inset-0 bg-black/25 backdrop-blur-sm" />
      </TransitionChild>

      <div class="fixed inset-0 overflow-y-auto">
        <div class="flex min-h-full items-center justify-center p-4 text-center">
          <TransitionChild
            as="template"
            enter="duration-300 ease-out"
            enter-from="opacity-0 scale-95"
            enter-to="opacity-100 scale-100"
            leave="duration-200 ease-in"
            leave-from="opacity-100 scale-100"
            leave-to="opacity-0 scale-95"
          >
            <DialogPanel class="w-full max-w-3xl transform overflow-hidden rounded-2xl bg-white px-8 py-6 text-left align-middle shadow-2xl transition-all">
              
              <!-- Header -->
              <div class="flex justify-between items-start mb-6">
                  <div>
                    <DialogTitle as="h3" class="text-2xl font-bold text-zinc-900 tracking-tight">
                        {{ roomName }}
                    </DialogTitle>
                    <div class="text-sm text-zinc-400 mt-1 font-medium">未來一週預約狀況</div>
                  </div>
                  <button @click="emit('close')" class="text-zinc-400 hover:text-black transition-colors p-2 -mr-2 -mt-2">
                      <XMarkIcon class="w-6 h-6" />
                  </button>
              </div>

              <!-- Visual Schedule Container -->
              <div class="relative pt-2"> 
                 
                  <!-- Axis Labels & Ticks -->
                 <div class="relative h-6 mb-1">
                    <div 
                        v-for="i in 12" 
                        :key="i" 
                        class="absolute top-0 flex flex-col items-center"
                        :style="{ left: ((i-1) / 11) * 100 + '%', transform: 'translateX(-50%)' }"
                    >
                        <span class="text-[10px] uppercase tracking-wider text-zinc-400 font-mono mb-1">
                            {{ 7 + i < 10 ? '0' + (7 + i) : (7 + i) }}:00
                        </span>
                        <!-- Tick Mark -->
                        <div class="w-px h-1 bg-zinc-200"></div>
                    </div>
                 </div>

                 <!-- Global Grid Lines (Background) -->
                 <!-- Align lines exactly with ticks. i=1 is 0%, i=12 is 100% -->
                 <div class="absolute inset-0 top-7 flex pointer-events-none" aria-hidden="true">
                    <!-- We render 12 lines. The first and last align with edges. -->
                    <div v-for="i in 12" :key="i" 
                         class="absolute top-0 bottom-0 w-px border-l border-dashed border-zinc-100"
                         :class="{ 'border-transparent': i === 1 || i === 12 }" 
                         :style="{ left: ((i-1) / 11) * 100 + '%' }"
                    ></div>
                 </div>

                 <!-- Content: 7 Day Rows -->
                 <div class="space-y-5 relative z-10 mt-2">
                    <div v-for="day in next7Days" :key="day.date" class="relative group">
                        <!-- Day Label -->
                        <div class="text-xs font-bold text-zinc-900 mb-1 flex items-center justify-between">
                            <span>{{ day.label }}</span>
                            <span v-if="day.date === today.toISOString().split('T')[0]" class="text-[10px] text-white bg-black px-1.5 py-0.5 rounded font-medium">TODAY</span>
                        </div>

                        <!-- Timeline Bar -->
                        <div class="h-6 w-full bg-zinc-50 border border-zinc-100 rounded-sm relative overflow-hidden">
                            <!-- Bookings -->
                            <div 
                               v-for="booking in bookings.filter(b => b.start_date === day.date)" 
                               :key="booking.id"
                               class="absolute top-0 bottom-0 bg-zinc-700 hover:bg-zinc-900 transition-colors z-10 flex items-center justify-center cursor-help group/block"
                               :style="{ left: getPosition(booking.start_time) + '%', width: getWidth(booking.start_time, booking.end_time) + '%' }"
                               :title="booking.applicant_name + ' (' + booking.start_time + '-' + booking.end_time + ')'"
                            >
                               <!-- Tooltip/Label inside block if wide enough -->
                               <span class="text-[10px] text-white font-mono opacity-0 group-hover/block:opacity-100 whitespace-nowrap overflow-hidden px-1">
                                   {{ booking.start_time }}
                               </span>
                            </div>
                        </div>
                    </div>
                 </div>
              </div>

            </DialogPanel>
          </TransitionChild>
        </div>
      </div>
    </Dialog>
  </TransitionRoot>
</template>
