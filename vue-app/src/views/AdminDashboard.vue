
<script setup>
import { ref, onMounted, watch, computed } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { 
  CheckIcon, 
  XMarkIcon, 
  ArchiveBoxArrowDownIcon,
  // TrashIcon, // Use Lucide instead
  ArrowUpTrayIcon,
  ArrowDownTrayIcon
} from '@heroicons/vue/20/solid'
import { MoreHorizontal, Trash, Power, FileEdit, Search, LayoutDashboard } from 'lucide-vue-next'
import { toast } from 'vue-sonner'
import ConfirmModal from '../components/ConfirmModal.vue'
import * as XLSX from 'xlsx'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Button } from '@/components/ui/button'

import DashboardOverview from '../components/DashboardOverview.vue'

const router = useRouter()
const orders = ref([])
const loading = ref(true)
const activeTab = ref('OVERVIEW') // OVERVIEW | PENDING | APPROVED | HISTORY
const users = ref([])

function triggerToast(message, type = 'success') {
  if (type === 'error') {
    toast.error(message)
  } else {
    toast.success(message)
  }
}

// Modal State
const showModal = ref(false)
const modalConfig = ref({
  title: '',
  message: '',
  confirmText: '確定',
  cancelText: '取消',
  isDanger: false,
  onConfirm: () => {}
})

function openModal(config) {
  modalConfig.value = {
    ...modalConfig.value,
    ...config,
    onConfirm: () => {
      config.onConfirm()
      showModal.value = false
    }
  }
  showModal.value = true
}

onMounted(() => {
    fetchOrders()
    // Explicitly fetch inventory if needed or handled by watch?
    // Let's just fetch orders initially.
    fetchInventory()
})

async function updateStatus(orderId, newStatus) {
  openModal({
    title: '更新訂單狀態',
    message: `確定要將此訂單標記為 ${newStatus} 嗎?`,
    confirmText: '確定',
    onConfirm: async () => {
      const { error } = await supabase
        .from('orders')
        .update({ status: newStatus })
        .eq('id', orderId)

      if (error) {
        console.error('Update Error:', error)
        triggerToast('更新失敗: ' + error.message, 'error')
      } else {
        // Refresh local data
        const idx = orders.value.findIndex(o => o.id === orderId)
        if (idx !== -1) orders.value[idx].status = newStatus
        triggerToast('狀態更新成功')
      }
    }
  })
}

async function deleteOrder(orderId) {
  openModal({
    title: '刪除訂單',
    message: '確定要刪除此筆訂單紀錄嗎? (此動作無法復原)',
    isDanger: true,
    confirmText: '刪除',
    onConfirm: async () => {
      const { error } = await supabase
        .from('orders')
        .delete()
        .eq('id', orderId)

      if (error) {
        console.error('Delete Error:', error)
        triggerToast('刪除失敗: ' + error.message, 'error')
      } else {
        // Remove from local list
        orders.value = orders.value.filter(o => o.id !== orderId)
        triggerToast('刪除成功')
      }
    }
  })
}

async function fetchOrders() {
  loading.value = true
  // Fetch orders with items
  const { data, error } = await supabase
    .from('orders')
    .select(`
      *,
      order_items (
        id,
        item_name_snapshot,
        quantity,
        items ( category )
      )
    `)
    .order('created_at', { ascending: false })

  if (error) {
    console.error(error)
  } else {
    orders.value = data
  }
  loading.value = false
}

// --- Inventory Management ---
const inventoryItems = ref([])
const searchQuery = ref('')
const newItem = ref({
  custom_id: '',
  name: '',
  category: '',
  total_stock: 1,
  safety_stock: null
})

function handleNavigation({ status }) {
    if (status === 'PENDING') {
        activeTab.value = 'PENDING'
    } else if (['APPROVED', 'DUE_SOON', 'OVERDUE'].includes(status) || status === 'COMPLETED') {
        activeTab.value = 'APPROVED'
    } else {
         activeTab.value = 'HISTORY'
    }
}

// Pagination State
const currentInventoryPage = ref(1)
const itemsPerPage = ref(10)

const filteredInventory = computed(() => {
  if (!searchQuery.value) return inventoryItems.value
  const lowerQuery = searchQuery.value.toLowerCase()
  return inventoryItems.value.filter(item => 
    (item.name && item.name.toLowerCase().includes(lowerQuery)) ||
    (item.custom_id && item.custom_id.toLowerCase().includes(lowerQuery)) ||
    (item.category && item.category.toLowerCase().includes(lowerQuery))
  )
})

const totalInventoryPages = computed(() => Math.ceil(filteredInventory.value.length / itemsPerPage.value))

const paginatedInventory = computed(() => {
  const start = (currentInventoryPage.value - 1) * itemsPerPage.value
  const end = start + itemsPerPage.value
  return filteredInventory.value.slice(start, end)
})

// Reset pagination when filter changes
watch([searchQuery, activeTab], () => {
    currentInventoryPage.value = 1
})

async function fetchInventory() {
    let query = supabase.from('items').select('*').order('created_at', { ascending: false })
    
    if (activeTab.value === 'INVENTORY') {
        query = query.eq('type', 'EQUIPMENT')
    } else if (activeTab.value === 'CONSUMABLES') {
        query = query.eq('type', 'CONSUMABLE')
    }
    
    const { data, error } = await query
    if (!error) inventoryItems.value = data
}

// Watch for tab change to fetch inventory
// Watch for tab change to fetch inventory
// Watch for tab change is combined below

const addingItem = ref(false)

async function addItem() {
    if (addingItem.value) return
    addingItem.value = true

    try {
        const trimmedId = newItem.value.custom_id ? newItem.value.custom_id.trim() : ''

        // Check for duplicate custom_id if provided (Global Uniqueness Check)
        if (trimmedId) {
            const { data: existingList, error: checkError } = await supabase
                .from('items')
                .select('id')
                .eq('custom_id', trimmedId)
            
            if (checkError) {
                console.error('Check Duplicate Error:', checkError)
                triggerToast('檢查 ID 時發生錯誤', 'error')
                return 
            }

            if (existingList && existingList.length > 0) {
                triggerToast('新增失敗: 此 ID 已存在', 'error')
                return
            }
        }

        const payload = {
            custom_id: trimmedId || null, // Ensure empty string becomes null or stored as empty? DB likely allows null.
            name: newItem.value.name,
            category: newItem.value.category,
            total_stock: newItem.value.total_stock,
            type: activeTab.value === 'CONSUMABLES' ? 'CONSUMABLE' : 'EQUIPMENT'
        }
        
        if (newItem.value.safety_stock !== null && newItem.value.safety_stock !== '') {
            payload.safety_stock = newItem.value.safety_stock
        }

        const { error } = await supabase.from('items').insert(payload)
        
        if (error) {
            triggerToast('新增失敗: ' + error.message, 'error')
        } else {
            newItem.value = { custom_id: '', name: '', category: '', total_stock: 1, safety_stock: null }
            fetchInventory()
            triggerToast(activeTab.value === 'CONSUMABLES' ? '耗材新增成功' : '器材新增成功')
        }
    } finally {
        addingItem.value = false
    }
}

async function toggleActive(item) {
    const { error } = await supabase.from('items').update({ is_active: !item.is_active }).eq('id', item.id)
    if (!error) {
        item.is_active = !item.is_active
    }
}

async function deleteItem(itemId) {
    openModal({
        title: '刪除器材',
        message: '確定要刪除此器材嗎? (此動作無法復原)',
        isDanger: true,
        confirmText: '刪除',
        onConfirm: async () => {
            const { error } = await supabase.from('items').delete().eq('id', itemId)
            
            if (error) {
                triggerToast('刪除失敗: ' + error.message, 'error')
            } else {
                inventoryItems.value = inventoryItems.value.filter(i => i.id !== itemId)
                triggerToast('刪除成功')
            }
        }
    })
}

// --- Excel Import/Export ---
function exportExcel() {
    const data = inventoryItems.value.map(item => ({
        'ID': item.custom_id,
        '名稱': item.name,
        '分類': item.category,
        '總庫存': item.total_stock,
        '狀態': item.is_active ? '上架中' : '已下架'
    }))

    const ws = XLSX.utils.json_to_sheet(data)
    const wb = XLSX.utils.book_new()
    XLSX.utils.book_append_sheet(wb, ws, activeTab.value === 'CONSUMABLES' ? '耗材清單' : '器材清單')
    XLSX.writeFile(wb, activeTab.value === 'CONSUMABLES' ? 'consumables_list.xlsx' : 'equipment_list.xlsx')
    triggerToast('匯出成功')
}

const fileInputRef = ref(null)

function triggerFileInput() {
    fileInputRef.value.click()
}

function handleFileUpload(event) {
    const file = event.target.files[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = async (e) => {
        try {
            const data = new Uint8Array(e.target.result)
            const workbook = XLSX.read(data, { type: 'array' })
            const firstSheetName = workbook.SheetNames[0]
            const worksheet = workbook.Sheets[firstSheetName]
            const jsonData = XLSX.utils.sheet_to_json(worksheet)

            let successCount = 0
            let failCount = 0
            
            // Expected columns: ID, 名稱, 分類, 總庫存
            for (const row of jsonData) {
                if (!row['名稱'] || !row['分類']) {
                    failCount++
                    continue
                }

                const { error } = await supabase.from('items').insert({
                    custom_id: row['ID'] ? String(row['ID']) : null,
                    name: row['名稱'],
                    category: row['分類'],
                    total_stock: row['總庫存'] || 1,
                    category: row['分類'],
                    total_stock: row['總庫存'] || 1,
                    is_active: true,
                    type: activeTab.value === 'CONSUMABLES' ? 'CONSUMABLE' : 'EQUIPMENT'
                })
                
                if (!error) successCount++
                else failCount++
            }
            
            triggerToast(`匯入完成: 成功 ${successCount} 筆, 失敗 ${failCount} 筆`)
            fetchInventory()
            
        } catch (error) {
            console.error(error)
            triggerToast('匯入失敗: 檔案格式錯誤', 'error')
        }
        // Reset input
        event.target.value = ''
    }
    reader.readAsArrayBuffer(file)
}

// --- User Management ---
// users ref is defined at top level
const newUser = ref({
    username: '',
    name: '',
    password: '',
    role: ['USER'] // Default role
})

// User Pagination
const currentUserPage = ref(1)
const totalUserPages = computed(() => Math.ceil(users.value.length / itemsPerPage.value))
const paginatedUsers = computed(() => {
    const start = (currentUserPage.value - 1) * itemsPerPage.value
    const end = start + itemsPerPage.value
    return users.value.slice(start, end)
})

async function fetchUsers() {
    const { data, error } = await supabase.from('users').select('*').order('created_at', { ascending: false })
    if (!error) users.value = data
}

watch(activeTab, (newTab) => {
    if (newTab === 'INVENTORY' || newTab === 'CONSUMABLES') fetchInventory()
    if (newTab === 'USERS') fetchUsers()
    // Reset User Pagination
    if (newTab === 'USERS') currentUserPage.value = 1
})

async function addUser() {
    // Basic validation
    if (!newUser.value.username || !newUser.value.password || !newUser.value.name || newUser.value.role.length === 0) return

    // Check for duplicates
    const { data: existingUser } = await supabase
        .from('users')
        .select('id')
        .eq('username', newUser.value.username)
        .single()
    
    if (existingUser) {
        triggerToast('新增失敗: 帳號已存在', 'error')
        return
    }

    const { error } = await supabase.from('users').insert({
        username: newUser.value.username,
        name: newUser.value.name,
        password: newUser.value.password,
        role: newUser.value.role
    })
    
    if (error) {
        triggerToast('新增失敗: ' + error.message, 'error')
    } else {
        newItem.value = { custom_id: '', name: '', category: '', total_stock: 1 } 
        newUser.value = { username: '', name: '', password: '', role: ['USER'] }
        fetchUsers()
        triggerToast('人員新增成功')
    }
}

async function deleteUser(userId) {
    openModal({
        title: '刪除使用者',
        message: '確定要刪除此使用者嗎?',
        isDanger: true,
        confirmText: '刪除',
        onConfirm: async () => {
            const { error } = await supabase.from('users').delete().eq('id', userId)
            if (error) {
                triggerToast('刪除失敗: ' + error.message, 'error')
            } else {
                fetchUsers()
                triggerToast('刪除成功')
            }
        }
    })
}



// --- History Export ---
function exportHistoryExcel() {
    const historyOrders = orders.value.filter(o => ['REJECTED', 'RETURNED', 'CANCELLED', 'COMPLETED'].includes(o.status))
    
    if (historyOrders.length === 0) {
        triggerToast('無歷史紀錄可匯出', 'error')
        return
    }

    const data = historyOrders.map(order => {
        // Format items string
        const itemsStr = order.order_items.map(oi => {
           return `${oi.item_name_snapshot} x${oi.quantity}`
        }).join(', ')

        return {
            '申請日期': new Date(order.created_at).toLocaleDateString(),
            '申請人': order.applicant_name,
            '用途': order.purpose,
            '物品內容': itemsStr,
            '借用日期': order.start_date || '-',
            '歸還日期': order.expected_return_date || '-',
            '狀態': order.status === 'COMPLETED' ? '已領用' :
                     order.status === 'RETURNED' ? '已歸還' :
                     order.status === 'REJECTED' ? '已拒絕' :
                     order.status === 'CANCELLED' ? '已取消' : order.status
        }
    })

    const ws = XLSX.utils.json_to_sheet(data)
    const wb = XLSX.utils.book_new()
    XLSX.utils.book_append_sheet(wb, ws, '歷史紀錄')
    XLSX.writeFile(wb, `history_records_${new Date().toISOString().split('T')[0]}.xlsx`)
    triggerToast('匯出成功')
}
// End History Export

</script>

<template>
  <div>
    <!-- Header -->
    <div class="flex justify-between items-center mb-6">
      <h1 class="text-2xl font-bold text-zinc-900 tracking-tight">後台管理系統</h1>
    </div>


    <!-- Tabs -->
    <div class="border-b border-zinc-200 mb-6">
      <nav class="-mb-px flex space-x-8 overflow-x-auto">
        <button 
          @click="activeTab = 'OVERVIEW'"
          :class="activeTab === 'OVERVIEW' ? 'border-zinc-900 text-zinc-900' : 'border-transparent text-zinc-500 hover:text-zinc-700 hover:border-zinc-300'"
          class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors"
        >
          總覽
        </button>

        <button 
          @click="activeTab = 'PENDING'"
          :class="activeTab === 'PENDING' ? 'border-zinc-900 text-zinc-900' : 'border-transparent text-zinc-500 hover:text-zinc-700 hover:border-zinc-300'"
          class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors"
        >
          待審核
          <span v-if="orders.filter(o => o.status === 'PENDING').length" class="bg-zinc-100 text-zinc-700 py-0.5 px-2 rounded-full text-xs border border-zinc-200">
            {{ orders.filter(o => o.status === 'PENDING').length }}
          </span>
        </button>
        
        <button 
          @click="activeTab = 'APPROVED'"
          :class="activeTab === 'APPROVED' ? 'border-zinc-900 text-zinc-900' : 'border-transparent text-zinc-500 hover:text-zinc-700 hover:border-zinc-300'"
          class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors"
        >
          借用中
          <span v-if="orders.filter(o => o.status === 'APPROVED').length" class="bg-zinc-100 text-zinc-700 py-0.5 px-2 rounded-full text-xs border border-zinc-200">
            {{ orders.filter(o => o.status === 'APPROVED').length }}
          </span>
        </button>

        <button 
          @click="activeTab = 'HISTORY'"
          :class="activeTab === 'HISTORY' ? 'border-zinc-900 text-zinc-900' : 'border-transparent text-zinc-500 hover:text-zinc-700 hover:border-zinc-300'"
          class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm transition-colors"
        >
          歷史紀錄
        </button>

        <button 
          @click="activeTab = 'INVENTORY'"
          :class="activeTab === 'INVENTORY' ? 'border-zinc-900 text-zinc-900' : 'border-transparent text-zinc-500 hover:text-zinc-700 hover:border-zinc-300'"
          class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors"
        >
          器材管理
        </button>

        <button 
          @click="activeTab = 'CONSUMABLES'"
          :class="activeTab === 'CONSUMABLES' ? 'border-zinc-900 text-zinc-900' : 'border-transparent text-zinc-500 hover:text-zinc-700 hover:border-zinc-300'"
          class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors"
        >
          耗材管理
        </button>
        
        <button 
          @click="activeTab = 'USERS'"
          :class="activeTab === 'USERS' ? 'border-zinc-900 text-zinc-900' : 'border-transparent text-zinc-500 hover:text-zinc-700 hover:border-zinc-300'"
          class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors"
        >
          人員管理
        </button>
      </nav>
    </div>

    <!-- Overview Tab Content -->
    <div v-if="activeTab === 'OVERVIEW'" class="mb-8">
        <DashboardOverview 
          :orders="orders" 
          :inventory="inventoryItems" 
          @navigate="handleNavigation"
        />
    </div>

    <!-- Inventory / Consumables Tab Content -->
    <div v-if="activeTab === 'INVENTORY' || activeTab === 'CONSUMABLES'">
      
      <!-- Excel Actions -->


      <!-- Add Item Form -->
      <div class="bg-white p-6 rounded-lg border border-zinc-200 mb-6 shadow-sm">
        <h3 class="text-base font-bold text-zinc-900 mb-4">{{ activeTab === 'CONSUMABLES' ? '新增耗材' : '新增器材' }}</h3>
        <div class="grid grid-cols-1 md:grid-cols-6 gap-4 items-end">
          <div>
            <label class="block text-xs font-semibold text-zinc-700 mb-1">ID</label>
            <input v-model="newItem.custom_id" type="text" class="h-10 w-full border border-zinc-200 bg-white rounded-md px-3 shadow-sm focus:border-zinc-900 focus:ring-zinc-900 sm:text-sm placeholder:text-zinc-400 transition-colors" placeholder="選填">
          </div>
          <div class="md:col-span-2">
            <label class="block text-xs font-semibold text-zinc-700 mb-1">{{ activeTab === 'CONSUMABLES' ? '耗材名稱' : '器材名稱' }}</label>
            <input v-model="newItem.name" type="text" class="h-10 w-full border border-zinc-200 bg-white rounded-md px-3 shadow-sm focus:border-zinc-900 focus:ring-zinc-900 sm:text-sm placeholder:text-zinc-400 transition-colors" placeholder="必填">
          </div>
          <div>
            <label class="block text-xs font-semibold text-zinc-700 mb-1">分類</label>
            <input v-model="newItem.category" type="text" class="h-10 w-full border border-zinc-200 bg-white rounded-md px-3 shadow-sm focus:border-zinc-900 focus:ring-zinc-900 sm:text-sm placeholder:text-zinc-400 transition-colors" placeholder="必填">
          </div>
          <div>
            <label class="block text-xs font-semibold text-zinc-700 mb-1">總庫存</label>
            <input v-model.number="newItem.total_stock" type="number" class="h-10 w-full border border-zinc-200 bg-white rounded-md px-3 shadow-sm focus:border-zinc-900 focus:ring-zinc-900 sm:text-sm placeholder:text-zinc-400 transition-colors" placeholder="1">
          </div>
          <div>
            <label class="block text-xs font-semibold text-zinc-700 mb-1">安全庫存量</label>
            <input v-model.number="newItem.safety_stock" type="number" class="h-10 w-full border border-zinc-200 bg-white rounded-md px-3 shadow-sm focus:border-zinc-900 focus:ring-zinc-900 sm:text-sm placeholder:text-zinc-400 transition-colors" placeholder="選填">
          </div>
          <div class="md:col-span-6 flex justify-end mt-2">
             <button @click="addItem" :disabled="!newItem.name || !newItem.category || addingItem" class="h-10 px-6 bg-zinc-900 text-white rounded-md hover:bg-zinc-800 disabled:opacity-50 text-sm font-medium transition-colors flex items-center justify-center">
                {{ addingItem ? '處理中' : (activeTab === 'CONSUMABLES' ? '新增耗材' : '新增器材') }}
             </button>
          </div>
        </div>
      </div>

      <!-- Toolbar (Search & Actions) -->
      <div class="flex flex-col sm:flex-row justify-between items-center gap-4 mb-4">
        <!-- Search -->
        <div class="relative w-full sm:w-64">
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <Search class="h-4 w-4 text-zinc-400" />
            </div>
            <input v-model="searchQuery" type="text" class="pl-10 h-10 w-full border-zinc-300 rounded-md shadow-sm focus:border-zinc-900 focus:ring-zinc-900 sm:text-sm" placeholder="搜尋名稱、ID...">
        </div>

        <!-- Excel Actions -->
        <div class="flex gap-2 w-full sm:w-auto">
            <button @click="exportExcel" class="flex-1 sm:flex-none h-10 flex items-center justify-center gap-2 bg-white text-zinc-900 border border-zinc-200 px-4 rounded-md shadow-sm hover:bg-zinc-50 transition text-sm font-medium">
                <ArrowDownTrayIcon class="w-4 h-4" /> 匯出 Excel
            </button>
            <button @click="triggerFileInput" class="flex-1 sm:flex-none h-10 flex items-center justify-center gap-2 bg-white text-zinc-900 border border-zinc-200 px-4 rounded-md shadow-sm hover:bg-zinc-50 transition text-sm font-medium">
                <ArrowUpTrayIcon class="w-4 h-4" /> 匯入 Excel
            </button>
            <input type="file" ref="fileInputRef" @change="handleFileUpload" accept=".xlsx, .xls" class="hidden" />
        </div>
      </div>

      <!-- Inventory List -->
      <div class="bg-white rounded-lg border border-zinc-200 overflow-x-auto">
        <table class="min-w-full divide-y divide-zinc-200">
          <thead class="bg-zinc-50">
            <tr>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider whitespace-nowrap">ID</th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider whitespace-nowrap">名稱</th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider whitespace-nowrap">分類</th>
              <th scope="col" class="px-6 py-3 text-center text-xs font-medium text-zinc-500 uppercase tracking-wider whitespace-nowrap">庫存</th>
              <th scope="col" class="px-6 py-3 text-center text-xs font-medium text-zinc-500 uppercase tracking-wider whitespace-nowrap">安全庫存</th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider whitespace-nowrap">狀態</th>
              <th scope="col" class="px-6 py-3 text-right text-xs font-medium text-zinc-500 uppercase tracking-wider whitespace-nowrap">操作</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-zinc-200">
            <tr v-for="item in paginatedInventory" :key="item.id" class="hover:bg-zinc-50 transition-colors">
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm text-zinc-900 font-mono">{{ item.custom_id || '-' }}</div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm font-medium text-zinc-900">{{ item.name }}</div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-zinc-500">{{ item.category }}</td>
              <td class="px-6 py-4 whitespace-nowrap text-center text-sm text-zinc-900">{{ item.total_stock }}</td>
              <td class="px-6 py-4 whitespace-nowrap text-center text-sm text-zinc-500">{{ item.safety_stock || '-' }}</td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="px-2 py-0.5 inline-flex text-xs leading-5 font-semibold rounded-md border" :class="item.is_active ? 'bg-white border-zinc-300 text-zinc-700' : 'bg-zinc-100 border-zinc-200 text-zinc-400'">
                  <span v-if="item.is_active" class="w-1.5 h-1.5 rounded-full bg-green-500 mr-1.5 my-auto"></span>
                  {{ item.is_active ? '上架中' : '已下架' }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <DropdownMenu>
                  <DropdownMenuTrigger class="inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 hover:bg-zinc-100 hover:text-zinc-900 h-8 w-8 p-0">
                    <span class="sr-only">Open menu</span>
                    <MoreHorizontal class="h-4 w-4" />
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem @click="toggleActive(item)">
                      <Power class="mr-2 h-4 w-4" />
                      <span>{{ item.is_active ? '下架' : '上架' }}</span>
                    </DropdownMenuItem>
                    <DropdownMenuSeparator />
                    <DropdownMenuItem @click="deleteItem(item.id)" class="text-red-600 focus:text-red-600 focus:bg-red-50">
                      <Trash class="mr-2 h-4 w-4" />
                      <span>刪除</span>
                    </DropdownMenuItem>
                    <!-- <DropdownMenuItem class="text-zinc-900">
                      <FileEdit class="mr-2 h-4 w-4" />
                      <span>編輯</span>
                    </DropdownMenuItem> -->
                  </DropdownMenuContent>
                </DropdownMenu>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Pagination Footer -->
      <div v-if="filteredInventory.length > 0" class="flex items-center justify-between mt-4 px-2">
           <div class="text-sm text-zinc-500">
               顯示 {{ (currentInventoryPage - 1) * itemsPerPage + 1 }} 到 {{ Math.min(currentInventoryPage * itemsPerPage, filteredInventory.length) }} 筆，共 {{ filteredInventory.length }} 筆
           </div>
           <div class="flex items-center gap-2">
               <button 
                @click="currentInventoryPage--" 
                :disabled="currentInventoryPage === 1"
                class="px-3 py-1 text-sm font-medium border border-zinc-200 rounded-md bg-white hover:bg-zinc-50 disabled:opacity-50 disabled:cursor-not-allowed text-zinc-700"
               >
                 上一頁
               </button>
               <span class="text-sm font-medium text-zinc-900">第 {{ currentInventoryPage }} 頁</span>
               <button 
                @click="currentInventoryPage++" 
                :disabled="currentInventoryPage >= totalInventoryPages"
                class="px-3 py-1 text-sm font-medium border border-zinc-200 rounded-md bg-white hover:bg-zinc-50 disabled:opacity-50 disabled:cursor-not-allowed text-zinc-700"
               >
                 下一頁
               </button>
           </div>
      </div>
    </div>

    <!-- User Management Tab Content -->
    <div v-if="activeTab === 'USERS'">
      <!-- Add User Form -->
      <div class="bg-white p-6 rounded-lg border border-zinc-200 mb-6 shadow-sm">
        <h3 class="text-base font-bold text-zinc-900 mb-4">新增人員</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4 items-end">
          <div>
            <label class="block text-xs font-semibold text-zinc-700 mb-1">姓名</label>
            <input v-model="newUser.name" type="text" class="w-full h-10 border border-zinc-200 bg-white rounded-md px-3 shadow-sm focus:border-zinc-900 focus:ring-zinc-900 sm:text-sm placeholder:text-zinc-400 transition-colors" placeholder="">
          </div>
          <div>
            <label class="block text-xs font-semibold text-zinc-700 mb-1">帳號</label>
            <input v-model="newUser.username" type="text" class="w-full h-10 border border-zinc-200 bg-white rounded-md px-3 shadow-sm focus:border-zinc-900 focus:ring-zinc-900 sm:text-sm placeholder:text-zinc-400 transition-colors" placeholder="">
          </div>
          <div>
            <label class="block text-xs font-semibold text-zinc-700 mb-1">密碼</label>
            <input v-model="newUser.password" type="text" class="w-full h-10 border border-zinc-200 bg-white rounded-md px-3 shadow-sm focus:border-zinc-900 focus:ring-zinc-900 sm:text-sm placeholder:text-zinc-400 transition-colors" placeholder="">
          </div>
           <!-- Removed Select -->
           <div>
            <label class="block text-xs font-semibold text-zinc-700 mb-1">角色</label>
            <div class="flex items-center gap-4 h-10">
                <label class="flex items-center gap-2 cursor-pointer group">
                    <div class="relative flex items-center">
                      <input type="checkbox" value="USER" v-model="newUser.role" class="peer h-4 w-4 rounded border-zinc-300 text-zinc-900 focus:ring-zinc-900 accent-zinc-900 transition-all cursor-pointer">
                    </div>
                    <span class="text-sm text-zinc-600 group-hover:text-zinc-900 transition-colors select-none whitespace-nowrap">一般使用者</span>
                </label>
                <label class="flex items-center gap-2 cursor-pointer group">
                    <div class="relative flex items-center">
                      <input type="checkbox" value="ADMIN" v-model="newUser.role" class="peer h-4 w-4 rounded border-zinc-300 text-zinc-900 focus:ring-zinc-900 accent-zinc-900 transition-all cursor-pointer">
                    </div>
                    <span class="text-sm text-zinc-600 group-hover:text-zinc-900 transition-colors select-none whitespace-nowrap">管理員</span>
                </label>
            </div>
          </div>
          <div>
             <button @click="addUser" :disabled="!newUser.username || !newUser.password || !newUser.name || newUser.role.length === 0" class="w-full bg-zinc-900 text-white px-4 py-2 rounded-md hover:bg-zinc-800 disabled:opacity-50 text-sm font-medium transition-colors">新增</button>
          </div>
        </div>
      </div>

      <!-- Users List -->
      <div class="bg-white rounded-lg border border-zinc-200 overflow-x-auto">
        <table class="min-w-full divide-y divide-zinc-200">
          <thead class="bg-zinc-50">
            <tr>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider whitespace-nowrap">姓名</th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider whitespace-nowrap">帳號</th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider whitespace-nowrap">角色</th>
              <th scope="col" class="px-6 py-3 text-right text-xs font-medium text-zinc-500 uppercase tracking-wider whitespace-nowrap">操作</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-zinc-200">
            <tr v-for="user in paginatedUsers" :key="user.id" class="hover:bg-zinc-50 transition-colors">
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm font-medium text-zinc-900">{{ user.name }}</div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-zinc-500">{{ user.username }}</td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span v-for="role in (Array.isArray(user.role) ? user.role : [user.role])" :key="role" class="px-2 py-0.5 inline-flex text-xs leading-5 font-semibold rounded-md border mr-1" :class="role === 'ADMIN' ? 'bg-zinc-900 text-white border-zinc-900' : 'bg-white border-zinc-300 text-zinc-700'">
                  {{ role === 'ADMIN' ? '管理員' : '一般使用者' }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <DropdownMenu v-if="user.username !== 'admin'">
                  <DropdownMenuTrigger class="inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 hover:bg-zinc-100 hover:text-zinc-900 h-8 w-8 p-0">
                    <span class="sr-only">Open menu</span>
                    <MoreHorizontal class="h-4 w-4" />
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem @click="deleteUser(user.id)" class="text-red-600 focus:text-red-600 focus:bg-red-50">
                      <Trash class="mr-2 h-4 w-4" />
                      <span>刪除</span>
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Pagination Footer -->
      <div v-if="users.length > 0" class="flex items-center justify-between mt-4 px-2">
           <div class="text-sm text-zinc-500">
               顯示 {{ (currentUserPage - 1) * itemsPerPage + 1 }} 到 {{ Math.min(currentUserPage * itemsPerPage, users.length) }} 筆，共 {{ users.length }} 筆
           </div>
           <div class="flex items-center gap-2">
               <button 
                @click="currentUserPage--" 
                :disabled="currentUserPage === 1"
                class="px-3 py-1 text-sm font-medium border border-zinc-200 rounded-md bg-white hover:bg-zinc-50 disabled:opacity-50 disabled:cursor-not-allowed text-zinc-700"
               >
                 上一頁
               </button>
               <span class="text-sm font-medium text-zinc-900">第 {{ currentUserPage }} 頁</span>
               <button 
                @click="currentUserPage++" 
                :disabled="currentUserPage >= totalUserPages"
                class="px-3 py-1 text-sm font-medium border border-zinc-200 rounded-md bg-white hover:bg-zinc-50 disabled:opacity-50 disabled:cursor-not-allowed text-zinc-700"
               >
                 下一頁
               </button>
           </div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading && !['INVENTORY', 'USERS', 'CONSUMABLES'].includes(activeTab)" class="text-center py-12 text-zinc-500">載入中...</div>

    <!-- Order List (Only show when NOT in Inventory or Users tab) -->
    <div v-if="!['OVERVIEW', 'INVENTORY', 'USERS', 'CONSUMABLES'].includes(activeTab) && !loading" class="space-y-4">
      
       <!-- History Actions (Only for History Tab) -->
       <div v-if="activeTab === 'HISTORY'" class="flex justify-end mb-2">
          <button @click="exportHistoryExcel" class="flex items-center justify-center gap-2 bg-white text-zinc-900 border border-zinc-200 px-4 py-2 rounded-md shadow-sm hover:bg-zinc-50 transition text-sm font-medium">
             <ArrowDownTrayIcon class="w-4 h-4" /> 匯出 Excel
          </button>
       </div>
      
       <!-- Empty State -->
       <div v-if="orders.filter(o => activeTab === 'HISTORY' ? ['REJECTED', 'RETURNED', 'CANCELLED', 'COMPLETED'].includes(o.status) : o.status === activeTab).length === 0" class="text-center py-12 bg-zinc-50 rounded-lg border border-dashed border-zinc-300">
         <p class="text-zinc-500">目前沒有資料</p>
       </div>

      <div 
        v-for="order in orders.filter(o => activeTab === 'HISTORY' ? ['REJECTED', 'RETURNED', 'CANCELLED', 'COMPLETED'].includes(o.status) : o.status === activeTab)" 
        :key="order.id"
        class="bg-white rounded-lg border border-zinc-200 p-6 transition hover:border-zinc-300"
      >
        <div class="flex flex-col sm:flex-row justify-between items-start gap-4">
          
          <!-- Info -->
          <div class="flex-1">
            <div class="flex items-center gap-2 mb-2">
              <span class="font-bold text-lg text-zinc-900">{{ order.applicant_name }}</span>
              
              <span class="px-2 py-0.5 rounded-md text-xs font-bold border ml-2" 
                :class="{
                  'bg-white border-zinc-300 text-zinc-700': order.status === 'PENDING',
                  'bg-zinc-900 text-white border-zinc-900': order.status === 'APPROVED' || order.status === 'COMPLETED',
                  'bg-zinc-100 text-zinc-400 border-zinc-200 line-through': order.status === 'REJECTED' || order.status === 'CANCELLED',
                  'bg-white text-zinc-500 border-zinc-200': order.status === 'RETURNED'
                }">
                <span v-if="order.status === 'APPROVED' || order.status === 'COMPLETED'" class="inline-block w-1.5 h-1.5 rounded-full bg-green-400 mr-1 mb-0.5"></span>
                 {{ 
                        order.status === 'PENDING' ? '待審核' :
                        order.status === 'APPROVED' ? '已核准' :
                        order.status === 'COMPLETED' ? '已領用' :
                        order.status === 'REJECTED' ? '已拒絕' :
                        order.status === 'RETURNED' ? '已歸還' : order.status
                 }}
              </span>
            </div>
            
            <div class="text-sm text-zinc-600 mb-2">
              <span class="font-medium text-zinc-900">用途:</span> {{ order.purpose }}
            </div>
            
            <div class="text-sm text-zinc-500 flex items-center gap-2 flex-wrap">
              <span class="bg-zinc-50 px-2 py-1 rounded border border-zinc-100">📅 {{ order.start_date }} ~ {{ order.end_date }}</span>
            </div>

            <!-- Items -->
            <div class="mt-4 border-t border-zinc-100 pt-3">
              <ul class="space-y-1">
                <li v-for="item in order.order_items" :key="item.id" class="text-sm flex justify-between text-zinc-700">
                  <span>{{ item.item_name_snapshot }}</span>
                  <span class="font-mono font-medium text-zinc-900">x{{ item.quantity }}</span>
                </li>
              </ul>
            </div>
          </div>

          <!-- Actions -->
          <div class="flex flex-col gap-2 min-w-[120px]">
            <!-- Pending Actions -->
            <template v-if="order.status === 'PENDING'">
              <button @click="updateStatus(order.id, 'APPROVED')" class="flex items-center justify-center gap-2 bg-zinc-900 text-white px-3 py-2 rounded-md hover:bg-zinc-800 transition text-sm font-medium">
                <CheckIcon class="w-3 h-3" /> 同意
              </button>
              <button @click="updateStatus(order.id, 'REJECTED')" class="flex items-center justify-center gap-2 bg-white border border-zinc-200 text-zinc-600 px-3 py-2 rounded-md hover:bg-zinc-50 hover:text-red-600 transition text-sm font-medium">
                <XMarkIcon class="w-3 h-3" /> 拒絕
              </button>
            </template>

            <!-- Approved Actions -->
            <template v-if="order.status === 'APPROVED'">
              <button @click="updateStatus(order.id, 'RETURNED')" class="flex items-center justify-center gap-2 bg-white border border-zinc-900 text-zinc-900 px-3 py-2 rounded-md hover:bg-zinc-50 transition text-sm font-medium">
                <ArchiveBoxArrowDownIcon class="w-3 h-3" /> 歸還
              </button>
            </template>

            <!-- History Actions -->
             <template v-if="['REJECTED', 'RETURNED', 'CANCELLED', 'COMPLETED'].includes(order.status)">
              <button @click="deleteOrder(order.id)" class="flex items-center justify-center gap-1 bg-white border border-zinc-200 text-zinc-400 px-3 py-2 rounded-md hover:bg-red-50 hover:border-red-200 hover:text-red-600 transition text-xs font-medium">
                <Trash class="w-3 h-3" /> 刪除紀錄
              </button>
            </template>
          </div>

        </div>
      </div>
    </div>

  </div>


  <ConfirmModal
    :isOpen="showModal"
    :title="modalConfig.title"
    :message="modalConfig.message"
    :confirmText="modalConfig.confirmText"
    :cancelText="modalConfig.cancelText"
    :isDanger="modalConfig.isDanger"
    @confirm="modalConfig.onConfirm"
    @cancel="showModal = false"
  />
</template>
