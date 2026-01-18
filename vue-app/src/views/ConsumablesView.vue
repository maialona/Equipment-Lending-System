<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '../lib/supabase'
import { useCartStore } from '../stores/cart'
import { PlusIcon } from '@heroicons/vue/20/solid'
import Skeleton from '@/components/ui/skeleton/Skeleton.vue'

const items = ref([])
const loading = ref(true)
const categories = ref([])
const selectedCategory = ref('全部')
const cart = useCartStore()

async function fetchItems() {
  loading.value = true
  // Fetch only consumables
  const { data, error } = await supabase
    .from('items')
    .select('*')
    .eq('is_active', true)
    .eq('type', 'CONSUMABLE')
    
  if (error) {
    console.error('Error fetching consumables:', error)
  } else {
    items.value = data
    // Extract unique categories
    const cats = new Set(data.map(i => i.category))
    categories.value = ['全部', ...cats]
  }
  loading.value = false
}

const filteredItems = computed(() => {
  if (selectedCategory.value === '全部') return items.value
  return items.value.filter(i => i.category === selectedCategory.value)
})

onMounted(() => {
  fetchItems()
})
</script>

<template>
  <div>
    <!-- Hero / Header -->
    <div class="mb-8 text-center sm:text-left">
      <h1 class="text-3xl font-bold text-foreground mb-2">耗材領用</h1>
      <p class="text-muted-foreground">請選擇您需要的耗材並加入清單。</p>
    </div>

    <!-- Category Filter -->
    <div class="flex flex-wrap gap-2 mb-6">
      <button 
        v-for="cat in categories" 
        :key="cat"
        @click="selectedCategory = cat"
        class="px-3 py-1.5 rounded-md text-sm font-medium transition-colors border"
        :class="selectedCategory === cat 
          ? 'bg-primary text-primary-foreground border-primary' 
          : 'bg-card text-muted-foreground border-border hover:bg-muted hover:text-foreground'"
      >
        {{ cat }}
      </button>
    </div>

    <!-- Loading State (Skeleton) -->
    <div v-if="loading" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="n in 6" :key="n" class="bg-card rounded-lg border border-border p-5 flex flex-col justify-between h-[180px]">
        <div>
          <div class="flex justify-between items-start mb-3">
             <Skeleton class="h-5 w-16 bg-muted" />
             <Skeleton class="h-5 w-12 bg-muted" />
          </div>
          <Skeleton class="h-6 w-3/4 mb-2" />
          <Skeleton class="h-4 w-1/2" />
        </div>
        <Skeleton class="h-9 w-full mt-4" />
      </div>
    </div>

    <!-- Empty State -->
    <div v-else-if="items.length === 0" class="text-center py-12 bg-card rounded-lg border border-dashed border-border">
        <p class="text-muted-foreground">目前沒有可用的耗材。</p>
    </div>

    <!-- Grid -->
    <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="item in filteredItems" :key="item.id" class="group bg-card rounded-lg border border-border p-5 flex flex-col justify-between hover:border-input transition-colors">
        
        <!-- Header -->
        <div>
          <div class="flex justify-between items-start mb-3">
             <!-- Category Tag Removed -->
             <div class="text-[10px] font-medium text-muted-foreground border border-border px-2 py-0.5 rounded bg-muted ml-auto">
                庫存: {{ item.total_stock }}
             </div>
          </div>
          <h3 class="text-lg font-bold text-foreground mb-1 leading-tight">{{ item.name }}</h3>
          <p class="text-xs text-muted-foreground font-mono" v-if="item.custom_id">{{ item.custom_id }}</p>
        </div>

        <!-- Action -->
        <button 
          @click="cart.addItem(item)"
          class="w-full mt-5 flex items-center justify-center gap-2 bg-zinc-900 text-white border border-transparent py-2 rounded-md hover:bg-zinc-800 transition-all text-sm font-medium opacity-0 group-hover:opacity-100"
        >
          <PlusIcon class="w-4 h-4" />
          加入清單
        </button>
      </div>
    </div>
  </div>
</template>
