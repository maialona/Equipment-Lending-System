
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
  ArrowDownTrayIcon,
  CalendarDaysIcon
} from '@heroicons/vue/20/solid'
import { MoreHorizontal, Trash, Power, FileEdit, Search, LayoutDashboard, ArrowUp, ArrowDown, ChevronRight, ChevronDown } from 'lucide-vue-next'
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
  try {
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

    if (error) throw error
    orders.value = data
  } catch (err) {
    console.error(err)
    triggerToast('無法載入訂單', 'error')
  } finally {
    loading.value = false
  }
}

// --- Accordion Grouping ---
const accordionState = ref({})

function toggleAccordion(key) {
    accordionState.value[key] = !accordionState.value[key]
}

const groupedOrders = computed(() => {
    // 1. Filter orders based on activeTab
    let filtered = []
    if (activeTab.value === 'HISTORY') {
        filtered = orders.value.filter(o => ['REJECTED', 'RETURNED', 'CANCELLED', 'COMPLETED'].includes(o.status))
    } else if (['PENDING', 'APPROVED'].includes(activeTab.value)) {
        filtered = orders.value.filter(o => o.status === activeTab.value)
    } else {
        // Fallback or other tabs
        return {}
    }

    // 2. Group by Applicant
    const groups = filtered.reduce((acc, order) => {
        const name = order.applicant_name || '未署名'
        if (!acc[name]) {
            acc[name] = []
            // Initialize accordion state if new (Details: Default Open)
            if (accordionState.value[name] === undefined) {
                 accordionState.value[name] = true 
            }
        }
        acc[name].push(order)
        return acc
    }, {})

    return groups
})

// --- Inventory Management ---
const inventoryItems = ref([])
const searchQuery = ref('')
// New Item Form State
const newItem = ref({
  custom_id: '',
  name: '',
  category: '',
  total_stock: 1,
  safety_stock: null
})

// --- Sorting State ---
const inventorySort = ref({ column: 'created_at', direction: 'desc' })
const userSort = ref({ column: 'created_at', direction: 'desc' })

function handleSort(type, column) {
    const state = type === 'INVENTORY' ? inventorySort : userSort
    if (state.value.column === column) {
        state.value.direction = state.value.direction === 'asc' ? 'desc' : 'asc'
    } else {
        state.value.column = column
        state.value.direction = 'asc'
    }
}

function sortData(data, sortState) {
    const { column, direction } = sortState
    if (!column) return data
    
    return [...data].sort((a, b) => {
        let valA = a[column]
        let valB = b[column]
        
        // Handle null/undefined
        if (valA === null || valA === undefined) valA = ''
        if (valB === null || valB === undefined) valB = ''
        
        // Numeric Check
        if (typeof valA === 'number' && typeof valB === 'number') {
            return direction === 'asc' ? valA - valB : valB - valA
        }
        
        // String Compare
        return direction === 'asc'
            ? String(valA).localeCompare(String(valB), 'zh-Hant')
            : String(valB).localeCompare(String(valA), 'zh-Hant')
    })
}

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
  let items = inventoryItems.value
  
  if (searchQuery.value) {
      const lowerQuery = searchQuery.value.toLowerCase()
      items = items.filter(item => 
        (item.name && item.name.toLowerCase().includes(lowerQuery)) ||
        (item.custom_id && item.custom_id.toLowerCase().includes(lowerQuery)) ||
        (item.category && item.category.toLowerCase().includes(lowerQuery))
      )
  }
  
  return sortData(items, inventorySort.value)
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
    try {
      let query = supabase.from('items').select('*').order('created_at', { ascending: false })
      
      if (activeTab.value === 'INVENTORY') {
          query = query.eq('type', 'EQUIPMENT')
      } else if (activeTab.value === 'CONSUMABLES') {
          query = query.eq('type', 'CONSUMABLE')
      }
      
      const { data, error } = await query
      if (error) throw error
      inventoryItems.value = data
    } catch (err) {
      console.error(err)
      triggerToast('無法載入庫存', 'error')
    }
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
const sortedUsers = computed(() => {
    return sortData(users.value, userSort.value)
})

const paginatedUsers = computed(() => {
    const start = (currentUserPage.value - 1) * itemsPerPage.value
    const end = start + itemsPerPage.value
    return sortedUsers.value.slice(start, end)
})

async function fetchUsers() {
    const { data, error } = await supabase.from('users').select('*').order('created_at', { ascending: false })
    if (!error) users.value = data
}

watch(activeTab, (newTab) => {
    if (newTab === 'INVENTORY' || newTab === 'CONSUMABLES' || newTab === 'OVERVIEW') fetchInventory()
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
    <div>
    <!-- Header -->
    <div class="flex justify-between items-center mb-6">
      <h1 class="text-2xl font-bold text-foreground tracking-tight">後台管理系統</h1>
    </div>


    <!-- Tabs -->
    <div class="border-b border-border mb-6">
      <nav class="-mb-px flex space-x-8 overflow-x-auto">
        <button 
          @click="activeTab = 'OVERVIEW'"
          :class="activeTab === 'OVERVIEW' ? 'border-primary text-primary' : 'border-transparent text-muted-foreground hover:text-foreground hover:border-border'"
          class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors"
        >
          總覽
        </button>

        <button 
          @click="activeTab = 'PENDING'"
          :class="activeTab === 'PENDING' ? 'border-primary text-primary' : 'border-transparent text-muted-foreground hover:text-foreground hover:border-border'"
          class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors"
        >
          待審核
          <span v-if="orders.filter(o => o.status === 'PENDING').length" class="bg-secondary text-secondary-foreground py-0.5 px-2 rounded-full text-xs border border-border">
            {{ orders.filter(o => o.status === 'PENDING').length }}
          </span>
        </button>
        
        <button 
          @click="activeTab = 'APPROVED'"
          :class="activeTab === 'APPROVED' ? 'border-primary text-primary' : 'border-transparent text-muted-foreground hover:text-foreground hover:border-border'"
          class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors"
        >
          借用中
          <span v-if="orders.filter(o => o.status === 'APPROVED').length" class="bg-secondary text-secondary-foreground py-0.5 px-2 rounded-full text-xs border border-border">
            {{ orders.filter(o => o.status === 'APPROVED').length }}
          </span>
        </button>

        <button 
          @click="activeTab = 'HISTORY'"
          :class="activeTab === 'HISTORY' ? 'border-primary text-primary' : 'border-transparent text-muted-foreground hover:text-foreground hover:border-border'"
          class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm transition-colors"
        >
          歷史紀錄
        </button>

        <button 
          @click="activeTab = 'INVENTORY'"
          :class="activeTab === 'INVENTORY' ? 'border-primary text-primary' : 'border-transparent text-muted-foreground hover:text-foreground hover:border-border'"
          class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors"
        >
          器材管理
        </button>

        <button 
          @click="activeTab = 'CONSUMABLES'"
          :class="activeTab === 'CONSUMABLES' ? 'border-primary text-primary' : 'border-transparent text-muted-foreground hover:text-foreground hover:border-border'"
          class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors"
        >
          耗材管理
        </button>
        
        <button 
          @click="activeTab = 'USERS'"
          :class="activeTab === 'USERS' ? 'border-primary text-primary' : 'border-transparent text-muted-foreground hover:text-foreground hover:border-border'"
          class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 transition-colors"
        >
          人員管理
        </button>
      </nav>
    </div>

    <!-- Overview Tab Content -->
    <Transition name="fade" mode="out-in">
    <div v-if="activeTab === 'OVERVIEW'" class="mb-8" key="overview">
        <DashboardOverview 
          :orders="orders" 
          :inventory="inventoryItems" 
          @navigate="handleNavigation"
        />
    </div>
    <div v-else-if="activeTab === 'INVENTORY' || activeTab === 'CONSUMABLES'" :key="activeTab">
      
      <!-- Excel Actions -->


      <!-- Add Item Form -->
      <div class="bg-card p-6 rounded-lg border border-border mb-6 shadow-sm">
        <h3 class="text-base font-bold text-foreground mb-4">{{ activeTab === 'CONSUMABLES' ? '新增耗材' : '新增器材' }}</h3>
        <div class="grid grid-cols-1 md:grid-cols-6 gap-4 items-end">
          <div>
            <label class="block text-xs font-semibold text-muted-foreground mb-1">ID</label>
            <input v-model="newItem.custom_id" type="text" class="h-10 w-full border border-input bg-background rounded-md px-3 shadow-sm focus:border-ring focus:ring-ring sm:text-sm placeholder:text-muted-foreground text-foreground transition-colors" placeholder="選填">
          </div>
          <div class="md:col-span-2">
            <label class="block text-xs font-semibold text-muted-foreground mb-1">{{ activeTab === 'CONSUMABLES' ? '耗材名稱' : '器材名稱' }}</label>
            <input v-model="newItem.name" type="text" class="h-10 w-full border border-input bg-background rounded-md px-3 shadow-sm focus:border-ring focus:ring-ring sm:text-sm placeholder:text-muted-foreground text-foreground transition-colors" placeholder="必填">
          </div>
          <div>
            <label class="block text-xs font-semibold text-muted-foreground mb-1">分類</label>
            <input v-model="newItem.category" type="text" class="h-10 w-full border border-input bg-background rounded-md px-3 shadow-sm focus:border-ring focus:ring-ring sm:text-sm placeholder:text-muted-foreground text-foreground transition-colors" placeholder="必填">
          </div>
          <div>
            <label class="block text-xs font-semibold text-muted-foreground mb-1">總庫存</label>
            <input v-model.number="newItem.total_stock" type="number" class="h-10 w-full border border-input bg-background rounded-md px-3 shadow-sm focus:border-ring focus:ring-ring sm:text-sm placeholder:text-muted-foreground text-foreground transition-colors" placeholder="1">
          </div>
          <div>
            <label class="block text-xs font-semibold text-muted-foreground mb-1">安全庫存量</label>
            <input v-model.number="newItem.safety_stock" type="number" class="h-10 w-full border border-input bg-background rounded-md px-3 shadow-sm focus:border-ring focus:ring-ring sm:text-sm placeholder:text-muted-foreground text-foreground transition-colors" placeholder="選填">
          </div>
          <div class="md:col-span-6 flex justify-end mt-2">
             <button @click="addItem" :disabled="!newItem.name || !newItem.category || addingItem" class="h-10 px-6 bg-primary text-primary-foreground rounded-md hover:bg-primary/90 disabled:opacity-50 text-sm font-medium transition-colors flex items-center justify-center">
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
                <Search class="h-4 w-4 text-muted-foreground" />
            </div>
            <input v-model="searchQuery" type="text" class="pl-10 h-10 w-full border border-input bg-background rounded-md shadow-sm focus:border-ring focus:ring-ring sm:text-sm text-foreground" placeholder="搜尋名稱、ID...">
        </div>

        <!-- Excel Actions -->
        <div class="flex gap-2 w-full sm:w-auto">
            <button @click="exportExcel" class="flex-1 sm:flex-none h-10 flex items-center justify-center gap-2 bg-card text-foreground border border-border px-4 rounded-md shadow-sm hover:bg-muted transition text-sm font-medium">
                <ArrowDownTrayIcon class="w-4 h-4" /> 匯出 Excel
            </button>
            <button @click="triggerFileInput" class="flex-1 sm:flex-none h-10 flex items-center justify-center gap-2 bg-card text-foreground border border-border px-4 rounded-md shadow-sm hover:bg-muted transition text-sm font-medium">
                <ArrowUpTrayIcon class="w-4 h-4" /> 匯入 Excel
            </button>
            <input type="file" ref="fileInputRef" @change="handleFileUpload" accept=".xlsx, .xls" class="hidden" />
        </div>
      </div>

      <!-- Inventory List -->
      <div class="bg-card rounded-lg border border-border overflow-x-auto">
        <table class="min-w-full divide-y divide-border">
          <thead class="bg-muted/50">
            <tr>
              <th @click="handleSort('INVENTORY', 'custom_id')" scope="col" class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider whitespace-nowrap cursor-pointer hover:bg-zinc-100 transition-colors select-none">
                  <div class="flex items-center gap-1">
                      ID
                      <ArrowUp v-if="inventorySort.column === 'custom_id' && inventorySort.direction === 'asc'" class="w-3 h-3 text-zinc-900" />
                      <ArrowDown v-if="inventorySort.column === 'custom_id' && inventorySort.direction === 'desc'" class="w-3 h-3 text-zinc-900" />
                  </div>
              </th>
              <th @click="handleSort('INVENTORY', 'name')" scope="col" class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider whitespace-nowrap cursor-pointer hover:bg-zinc-100 transition-colors select-none">
                  <div class="flex items-center gap-1">
                      名稱
                      <ArrowUp v-if="inventorySort.column === 'name' && inventorySort.direction === 'asc'" class="w-3 h-3 text-zinc-900" />
                      <ArrowDown v-if="inventorySort.column === 'name' && inventorySort.direction === 'desc'" class="w-3 h-3 text-zinc-900" />
                  </div>
              </th>
              <th @click="handleSort('INVENTORY', 'category')" scope="col" class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider whitespace-nowrap cursor-pointer hover:bg-zinc-100 transition-colors select-none">
                  <div class="flex items-center gap-1">
                      分類
                      <ArrowUp v-if="inventorySort.column === 'category' && inventorySort.direction === 'asc'" class="w-3 h-3 text-zinc-900" />
                      <ArrowDown v-if="inventorySort.column === 'category' && inventorySort.direction === 'desc'" class="w-3 h-3 text-zinc-900" />
                  </div>
              </th>
              <th @click="handleSort('INVENTORY', 'total_stock')" scope="col" class="px-6 py-3 text-center text-xs font-medium text-zinc-500 uppercase tracking-wider whitespace-nowrap cursor-pointer hover:bg-zinc-100 transition-colors select-none">
                  <div class="flex items-center justify-center gap-1">
                      庫存
                      <ArrowUp v-if="inventorySort.column === 'total_stock' && inventorySort.direction === 'asc'" class="w-3 h-3 text-zinc-900" />
                      <ArrowDown v-if="inventorySort.column === 'total_stock' && inventorySort.direction === 'desc'" class="w-3 h-3 text-zinc-900" />
                  </div>
              </th>
              <th @click="handleSort('INVENTORY', 'safety_stock')" scope="col" class="px-6 py-3 text-center text-xs font-medium text-zinc-500 uppercase tracking-wider whitespace-nowrap cursor-pointer hover:bg-zinc-100 transition-colors select-none">
                   <div class="flex items-center justify-center gap-1">
                      安全庫存
                      <ArrowUp v-if="inventorySort.column === 'safety_stock' && inventorySort.direction === 'asc'" class="w-3 h-3 text-zinc-900" />
                      <ArrowDown v-if="inventorySort.column === 'safety_stock' && inventorySort.direction === 'desc'" class="w-3 h-3 text-zinc-900" />
                  </div>
              </th>
              <th @click="handleSort('INVENTORY', 'is_active')" scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider whitespace-nowrap cursor-pointer hover:bg-muted transition-colors select-none">
                   <div class="flex items-center gap-1">
                      狀態
                      <ArrowUp v-if="inventorySort.column === 'is_active' && inventorySort.direction === 'asc'" class="w-3 h-3 text-foreground" />
                      <ArrowDown v-if="inventorySort.column === 'is_active' && inventorySort.direction === 'desc'" class="w-3 h-3 text-foreground" />
                  </div>
              </th>
              <th scope="col" class="px-6 py-3 text-right text-xs font-medium text-muted-foreground uppercase tracking-wider whitespace-nowrap">操作</th>
            </tr>
          </thead>
          <tbody class="bg-card divide-y divide-border">
            <tr v-for="item in paginatedInventory" :key="item.id" class="hover:bg-muted/50 transition-colors">
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm text-foreground font-mono">{{ item.custom_id || '-' }}</div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm font-medium text-foreground">{{ item.name }}</div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">{{ item.category }}</td>
              <td class="px-6 py-4 whitespace-nowrap text-center text-sm text-foreground">{{ item.total_stock }}</td>
              <td class="px-6 py-4 whitespace-nowrap text-center text-sm text-muted-foreground">{{ item.safety_stock || '-' }}</td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="px-2 py-0.5 inline-flex text-xs leading-5 font-semibold rounded-md border" :class="item.is_active ? 'bg-secondary border-transparent text-secondary-foreground' : 'bg-muted border-transparent text-muted-foreground'">
                  <span v-if="item.is_active" class="w-1.5 h-1.5 rounded-full bg-green-500 mr-1.5 my-auto"></span>
                  {{ item.is_active ? '上架中' : '已下架' }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <DropdownMenu>
                  <DropdownMenuTrigger class="inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 hover:bg-muted hover:text-foreground h-8 w-8 p-0">
                    <span class="sr-only">Open menu</span>
                    <MoreHorizontal class="h-4 w-4" />
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem @click="toggleActive(item)">
                      <Power class="mr-2 h-4 w-4" />
                      <span>{{ item.is_active ? '下架' : '上架' }}</span>
                    </DropdownMenuItem>
                    <DropdownMenuSeparator />
                    <DropdownMenuItem @click="deleteItem(item.id)" class="text-destructive focus:text-destructive focus:bg-destructive/10">
                      <Trash class="mr-2 h-4 w-4" />
                      <span>刪除</span>
                    </DropdownMenuItem>
                    <!-- <DropdownMenuItem class="text-foreground">
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
           <div class="text-sm text-muted-foreground">
               顯示 {{ (currentInventoryPage - 1) * itemsPerPage + 1 }} 到 {{ Math.min(currentInventoryPage * itemsPerPage, filteredInventory.length) }} 筆，共 {{ filteredInventory.length }} 筆
           </div>
           <div class="flex items-center gap-2">
               <button 
                @click="currentInventoryPage--" 
                :disabled="currentInventoryPage === 1"
                class="px-3 py-1 text-sm font-medium border border-border rounded-md bg-card hover:bg-muted disabled:opacity-50 disabled:cursor-not-allowed text-foreground"
               >
                 上一頁
               </button>
               <span class="text-sm font-medium text-foreground">第 {{ currentInventoryPage }} 頁</span>
               <button 
                @click="currentInventoryPage++" 
                :disabled="currentInventoryPage >= totalInventoryPages"
                class="px-3 py-1 text-sm font-medium border border-border rounded-md bg-card hover:bg-muted disabled:opacity-50 disabled:cursor-not-allowed text-foreground"
               >
                 下一頁
               </button>
           </div>
      </div>
    </div>

    <div v-else-if="activeTab === 'USERS'" key="users">
      <!-- Add User Form -->
      <div class="bg-card p-6 rounded-lg border border-border mb-6 shadow-sm">
        <h3 class="text-base font-bold text-foreground mb-4">新增人員</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4 items-end">
          <div>
            <label class="block text-xs font-semibold text-muted-foreground mb-1">姓名</label>
            <input v-model="newUser.name" type="text" class="w-full h-10 border border-input bg-background rounded-md px-3 shadow-sm focus:border-ring focus:ring-ring sm:text-sm placeholder:text-muted-foreground text-foreground transition-colors" placeholder="">
          </div>
          <div>
            <label class="block text-xs font-semibold text-muted-foreground mb-1">帳號</label>
            <input v-model="newUser.username" type="text" class="w-full h-10 border border-input bg-background rounded-md px-3 shadow-sm focus:border-ring focus:ring-ring sm:text-sm placeholder:text-muted-foreground text-foreground transition-colors" placeholder="">
          </div>
          <div>
            <label class="block text-xs font-semibold text-muted-foreground mb-1">密碼</label>
            <input v-model="newUser.password" type="text" class="w-full h-10 border border-input bg-background rounded-md px-3 shadow-sm focus:border-ring focus:ring-ring sm:text-sm placeholder:text-muted-foreground text-foreground transition-colors" placeholder="">
          </div>
           <!-- Removed Select -->
           <div>
            <label class="block text-xs font-semibold text-muted-foreground mb-1">角色</label>
            <div class="flex items-center gap-4 h-10">
                <label class="flex items-center gap-2 cursor-pointer group">
                    <div class="relative flex items-center">
                      <input type="checkbox" value="USER" v-model="newUser.role" class="peer h-4 w-4 rounded border-input text-primary focus:ring-ring accent-primary transition-all cursor-pointer">
                    </div>
                    <span class="text-sm text-muted-foreground group-hover:text-foreground transition-colors select-none whitespace-nowrap">一般使用者</span>
                </label>
                <label class="flex items-center gap-2 cursor-pointer group">
                    <div class="relative flex items-center">
                      <input type="checkbox" value="ADMIN" v-model="newUser.role" class="peer h-4 w-4 rounded border-input text-primary focus:ring-ring accent-primary transition-all cursor-pointer">
                    </div>
                    <span class="text-sm text-muted-foreground group-hover:text-foreground transition-colors select-none whitespace-nowrap">管理員</span>
                </label>
            </div>
          </div>
          <div>
             <button @click="addUser" :disabled="!newUser.username || !newUser.password || !newUser.name || newUser.role.length === 0" class="w-full bg-primary text-primary-foreground px-4 py-2 rounded-md hover:bg-primary/90 disabled:opacity-50 text-sm font-medium transition-colors">新增</button>
          </div>
        </div>
      </div>

      <!-- Users List -->
      <div class="bg-card rounded-lg border border-border overflow-x-auto">
        <table class="min-w-full divide-y divide-border">
          <thead class="bg-muted/50">
            <tr>
              <th @click="handleSort('USERS', 'name')" scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider whitespace-nowrap cursor-pointer hover:bg-muted transition-colors select-none">
                  <div class="flex items-center gap-1">
                      姓名
                      <ArrowUp v-if="userSort.column === 'name' && userSort.direction === 'asc'" class="w-3 h-3 text-foreground" />
                      <ArrowDown v-if="userSort.column === 'name' && userSort.direction === 'desc'" class="w-3 h-3 text-foreground" />
                  </div>
              </th>
              <th @click="handleSort('USERS', 'username')" scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider whitespace-nowrap cursor-pointer hover:bg-muted transition-colors select-none">
                  <div class="flex items-center gap-1">
                      帳號
                      <ArrowUp v-if="userSort.column === 'username' && userSort.direction === 'asc'" class="w-3 h-3 text-foreground" />
                      <ArrowDown v-if="userSort.column === 'username' && userSort.direction === 'desc'" class="w-3 h-3 text-foreground" />
                  </div>
              </th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider whitespace-nowrap">角色</th>
              <th scope="col" class="px-6 py-3 text-right text-xs font-medium text-muted-foreground uppercase tracking-wider whitespace-nowrap">操作</th>
            </tr>
          </thead>
          <tbody class="bg-card divide-y divide-border">
            <tr v-for="user in paginatedUsers" :key="user.id" class="hover:bg-muted/50 transition-colors">
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm font-medium text-foreground">{{ user.name }}</div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">{{ user.username }}</td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span v-for="role in (Array.isArray(user.role) ? user.role : [user.role])" :key="role" class="px-2 py-0.5 inline-flex text-xs leading-5 font-semibold rounded-md border mr-1" :class="role === 'ADMIN' ? 'bg-primary text-primary-foreground border-primary' : 'bg-card border-border text-muted-foreground'">
                  {{ role === 'ADMIN' ? '管理員' : '一般使用者' }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <DropdownMenu v-if="user.username !== 'admin'">
                  <DropdownMenuTrigger class="inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 hover:bg-muted hover:text-foreground h-8 w-8 p-0 text-muted-foreground">
                    <span class="sr-only">Open menu</span>
                    <MoreHorizontal class="h-4 w-4" />
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem @click="deleteUser(user.id)" class="text-destructive focus:text-destructive focus:bg-destructive/10">
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
           <div class="text-sm text-muted-foreground">
               顯示 {{ (currentUserPage - 1) * itemsPerPage + 1 }} 到 {{ Math.min(currentUserPage * itemsPerPage, users.length) }} 筆，共 {{ users.length }} 筆
           </div>
           <div class="flex items-center gap-2">
               <button 
                @click="currentUserPage--" 
                :disabled="currentUserPage === 1"
                class="px-3 py-1 text-sm font-medium border border-border rounded-md bg-card hover:bg-muted disabled:opacity-50 disabled:cursor-not-allowed text-foreground"
               >
                 上一頁
               </button>
               <span class="text-sm font-medium text-foreground">第 {{ currentUserPage }} 頁</span>
               <button 
                @click="currentUserPage++" 
                :disabled="currentUserPage >= totalUserPages"
                class="px-3 py-1 text-sm font-medium border border-border rounded-md bg-card hover:bg-muted disabled:opacity-50 disabled:cursor-not-allowed text-foreground"
               >
                 下一頁
               </button>
           </div>
      </div>
    </div>


    <div v-else class="space-y-4" key="orders-list">
       <div v-if="loading" class="text-center py-12 text-muted-foreground">載入中...</div>
       <div v-else class="space-y-4">
       <!-- History Actions (Only for History Tab) -->
       <div v-if="activeTab === 'HISTORY'" class="flex justify-end mb-2">
          <button @click="exportHistoryExcel" class="flex items-center justify-center gap-2 bg-white dark:bg-zinc-900 text-zinc-900 dark:text-zinc-100 border border-zinc-200 dark:border-zinc-800 px-4 py-2 rounded-md shadow-sm hover:bg-zinc-50 dark:hover:bg-zinc-800 transition text-sm font-medium">
             <ArrowDownTrayIcon class="w-4 h-4" /> 匯出 Excel
          </button>
       </div>
      
       <!-- Empty State -->
       <div v-if="Object.keys(groupedOrders).length === 0" class="text-center py-12 bg-muted/20 rounded-lg border border-dashed border-border">
         <p class="text-muted-foreground">目前沒有資料</p>
       </div>

       <!-- Grouped Orders (Accordion) -->
       <div v-else class="space-y-4">
          <div v-for="(groupOrders, applicant) in groupedOrders" :key="applicant" class="bg-card rounded-lg border border-border overflow-hidden">
              
              <!-- Accordion Header -->
              <div 
                @click="toggleAccordion(applicant)"
                class="flex items-center justify-between p-4 bg-muted/30 cursor-pointer hover:bg-muted/50 transition-colors select-none"
              >
                  <div class="flex items-center gap-3">
                      <div class="p-1 rounded bg-background border border-border text-muted-foreground transition-transform duration-200" :class="{ 'rotate-90': accordionState[applicant] }">
                          <ChevronRight class="w-4 h-4" />
                      </div>
                      <h3 class="font-bold text-foreground text-base">{{ applicant }}</h3>
                      <span class="text-xs font-medium px-2 py-0.5 rounded-full bg-primary/10 text-primary border border-primary/20">
                          {{ groupOrders.length }} 筆申請
                      </span>
                  </div>
              </div>

              <!-- Accordion Body (Smooth Transition) -->
              <div 
                class="grid transition-all duration-700 ease-in-out border-border" 
                :class="accordionState[applicant] ? 'grid-rows-[1fr] opacity-100 border-t' : 'grid-rows-[0fr] opacity-0 border-t-0'"
              >
                   <div class="overflow-hidden divide-y divide-border">
                   <div 
                    v-for="order in groupOrders" 
                    :key="order.id"
                    class="p-6 transition hover:bg-muted/10"
                   >
                    <div class="flex flex-col sm:flex-row justify-between items-start gap-4">
                      
                      <!-- Info -->
                      <div class="flex-1">
                        <div class="flex items-center gap-2 mb-2">
                          <!-- Status Badge -->
                          <span class="px-2 py-0.5 rounded-md text-xs font-bold border" 
                            :class="{
                              'bg-background border-border text-foreground': order.status === 'PENDING',
                              'bg-primary text-primary-foreground border-primary': order.status === 'APPROVED' || order.status === 'COMPLETED',
                              'bg-muted/50 text-muted-foreground border-border line-through': order.status === 'REJECTED' || order.status === 'CANCELLED',
                              'bg-background text-muted-foreground border-border': order.status === 'RETURNED'
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
                        
                        <div class="text-sm text-muted-foreground mb-2">
                          <span class="font-medium text-foreground">用途:</span> {{ order.purpose }}
                        </div>
                        
                        <div class="text-sm text-muted-foreground flex items-center gap-2 flex-wrap">
                          <span class="bg-muted px-2 py-1 rounded border border-border flex items-center">
                            <CalendarDaysIcon class="w-3.5 h-3.5 mr-1.5 text-black dark:text-white" />
                            {{ order.start_date }} ~ {{ order.end_date }}
                          </span>
                        </div>

                        <!-- Items -->
                        <div class="mt-4 border-t border-border pt-3">
                          <ul class="space-y-1">
                            <li v-for="item in order.order_items" :key="item.id" class="text-sm flex justify-between text-muted-foreground">
                              <span>{{ item.item_name_snapshot }}</span>
                              <span class="font-mono font-medium text-foreground">x{{ item.quantity }}</span>
                            </li>
                          </ul>
                        </div>
                      </div>

                      <!-- Actions -->
                      <div class="flex flex-col gap-2 min-w-[120px]">
                        <!-- Pending Actions -->
                        <template v-if="order.status === 'PENDING'">
                          <button @click="updateStatus(order.id, 'APPROVED')" class="flex items-center justify-center gap-2 bg-primary text-primary-foreground px-3 py-2 rounded-md hover:bg-primary/90 transition text-sm font-medium">
                            <CheckIcon class="w-3 h-3" /> 同意
                          </button>
                          <button @click="updateStatus(order.id, 'REJECTED')" class="flex items-center justify-center gap-2 bg-background border border-border text-muted-foreground px-3 py-2 rounded-md hover:bg-muted hover:text-destructive transition text-sm font-medium">
                            <XMarkIcon class="w-3 h-3" /> 拒絕
                          </button>
                        </template>

                        <!-- Approved Actions -->
                        <template v-if="order.status === 'APPROVED'">
                          <button @click="updateStatus(order.id, 'RETURNED')" class="flex items-center justify-center gap-2 bg-background border border-primary text-primary px-3 py-2 rounded-md hover:bg-secondary transition text-sm font-medium">
                            <ArchiveBoxArrowDownIcon class="w-3 h-3" /> 歸還
                          </button>
                        </template>

                        <!-- History Actions -->
                         <template v-if="['REJECTED', 'RETURNED', 'CANCELLED', 'COMPLETED'].includes(order.status)">
                          <button @click="deleteOrder(order.id)" class="flex items-center justify-center gap-1 bg-background border border-border text-muted-foreground px-3 py-2 rounded-md hover:bg-destructive/10 hover:border-destructive hover:text-destructive transition text-xs font-medium">
                            <Trash class="w-3 h-3" /> 刪除紀錄
                          </button>
                        </template>
                      </div>

                    </div>
                   </div>
                   </div>
              </div>
          </div>
       </div>
    </div>
    </div>


    </Transition>
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
  </div>
</template>
