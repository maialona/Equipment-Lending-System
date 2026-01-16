<script setup>
import { ref } from 'vue'
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
} from '@/components/ui/dropdown-menu'
import { Button } from '@/components/ui/button'

const logs = ref([])
const isOpen = ref(false)

function addLog(msg) {
  logs.value.unshift(`[${new Date().toLocaleTimeString()}] ${msg}`)
}

function handleOpenChange(val) {
    isOpen.value = val
    addLog(`Menu visible state changed: ${val}`)
}

function debugClick() {
    addLog('Trigger clicked (native click handler)')
}
</script>

<template>
  <div class="p-10 max-w-2xl mx-auto space-y-8">
    <h1 class="text-2xl font-bold">Debug Tools</h1>
    
    <div class="p-6 border rounded-lg bg-zinc-50">
      <h2 class="font-semibold mb-4">Dropdown Test Area</h2>
      
      <div class="flex gap-4 items-center mb-8">
        <!-- Direct minimal implementation -->
        <DropdownMenu @update:open="handleOpenChange">
            <DropdownMenuTrigger class="bg-zinc-900 text-white px-4 py-2 rounded-md hover:bg-zinc-800" @click="debugClick">
                 Click Me (Trigger)
            </DropdownMenuTrigger>
            <DropdownMenuContent class="w-56 bg-white z-[9999] border-zinc-200 shadow-xl" align="start" :side-offset="8">
                <DropdownMenuLabel class="text-xs font-bold text-zinc-500 uppercase tracking-wider">Debug Actions</DropdownMenuLabel>
                <DropdownMenuSeparator class="bg-zinc-100" />
                <DropdownMenuItem @click="addLog('Action 1 clicked')" class="hover:bg-zinc-100 cursor-pointer">
                    Action Item 1
                </DropdownMenuItem>
                <DropdownMenuItem @click="addLog('Action 2 clicked')" class="hover:bg-zinc-100 cursor-pointer">
                    Action Item 2
                </DropdownMenuItem>
                <DropdownMenuSeparator class="bg-zinc-100" />
                <DropdownMenuItem @click="addLog('Delete clicked')" class="text-red-600 hover:bg-red-50 cursor-pointer">
                    Delete
                </DropdownMenuItem>
            </DropdownMenuContent>
        </DropdownMenu>

        <div class="text-sm text-zinc-500">
            Current State: <span class="font-mono font-bold" :class="isOpen ? 'text-green-600' : 'text-zinc-400'">{{ isOpen ? 'OPEN' : 'CLOSED' }}</span>
        </div>
      </div>
    </div>

    <div class="p-4 border rounded-lg bg-zinc-900 text-zinc-50 font-mono text-sm h-64 overflow-y-auto">
        <div class="mb-2 text-zinc-400 border-b border-zinc-700 pb-2">Event Log:</div>
        <div v-if="logs.length === 0" class="text-zinc-600 italic">No events yet...</div>
        <div v-for="(log, i) in logs" :key="i" class="mb-1">
            {{ log }}
        </div>
    </div>
  </div>
</template>
