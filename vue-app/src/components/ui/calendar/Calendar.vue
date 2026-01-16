<script setup>
import {
  CalendarCell,
  CalendarCellTrigger,
  CalendarGrid,
  CalendarGridBody,
  CalendarGridHead,
  CalendarGridRow,
  CalendarHeadCell,
  CalendarHeader,
  CalendarHeading,
  CalendarNext,
  CalendarPrev,
  CalendarRoot,
} from 'radix-vue'
import { ChevronLeft, ChevronRight } from 'lucide-vue-next'
import { cn } from '@/lib/utils'
import { computed } from 'vue'

const props = defineProps({
  class: { type: String, default: '' },
  modelValue: { type: [String, Object, Date], default: undefined }, // Allow String/Object to handle CalendarDate
  weekdayFormat: { type: String, default: 'short' },
})

const emit = defineEmits(['update:modelValue'])

const delegatedProps = computed(() => {
  const { class: _, modelValue, ...delegated } = props
  return delegated
})

// Wrapper to handle v-model
const date = computed({
    get: () => props.modelValue,
    set: (val) => emit('update:modelValue', val)
})

</script>

<template>
  <CalendarRoot
    v-slot="{ grid, weekDays }"
    v-model="date"
    :class="cn('p-3', props.class)"
    v-bind="delegatedProps"
  >
    <CalendarHeader class="relative flex items-center justify-center pt-1">
      <CalendarPrev
        :class="cn(
          'inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50',
          'border border-input bg-background hover:bg-accent hover:text-accent-foreground',
          'h-7 w-7 bg-transparent p-0 opacity-50 hover:opacity-100',
          'absolute left-1',
        )"
      >
        <ChevronLeft class="h-4 w-4" />
      </CalendarPrev>
      <CalendarHeading class="text-sm font-medium" />
      <CalendarNext
        :class="cn(
          'inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50',
          'border border-input bg-background hover:bg-accent hover:text-accent-foreground',
          'h-7 w-7 bg-transparent p-0 opacity-50 hover:opacity-100',
          'absolute right-1',
        )"
      >
        <ChevronRight class="h-4 w-4" />
      </CalendarNext>
    </CalendarHeader>

    <div class="flex flex-col space-y-4 pt-4 sm:flex-row sm:gap-x-4 sm:space-y-0">
      <CalendarGrid v-for="month in grid" :key="month.value.toString()" class="w-full border-collapse space-y-1">
        <CalendarGridHead>
          <CalendarGridRow class="flex">
            <CalendarHeadCell
              v-for="day in weekDays"
              :key="day"
              class="w-9 rounded-md text-[0.8rem] font-normal text-muted-foreground"
            >
              {{ day }}
            </CalendarHeadCell>
          </CalendarGridRow>
        </CalendarGridHead>
        <CalendarGridBody class="grid">
          <CalendarGridRow
            v-for="(weekDates, index) in month.rows"
            :key="index"
            class="mt-2 flex w-full"
          >
            <CalendarCell
              v-for="weekDate in weekDates"
              :key="weekDate.toString()"
              :date="weekDate"
            >
              <CalendarCellTrigger
                :day="weekDate"
                :month="month.value"
                :class="cn(
                  'inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50',
                  'h-9 w-9 p-0 font-normal aria-selected:opacity-100',
                  // Today
                  'data-[today]:bg-accent data-[today]:text-accent-foreground', 
                  // Selected
                  'data-[selected]:bg-zinc-900 data-[selected]:text-zinc-50 data-[selected]:hover:bg-zinc-900 data-[selected]:hover:text-zinc-50 data-[selected]:focus:bg-zinc-900 data-[selected]:focus:text-zinc-50',
                  // Outside days
                  'data-[outside-view]:text-muted-foreground data-[outside-view]:opacity-50',
                  // Disabled
                  'data-[disabled]:text-muted-foreground data-[disabled]:opacity-50',
                  // Range Middle (if needed later)
                   // 'data-[highlighted]:bg-accent/50',
                )"
              />
            </CalendarCell>
          </CalendarGridRow>
        </CalendarGridBody>
      </CalendarGrid>
    </div>
  </CalendarRoot>
</template>
