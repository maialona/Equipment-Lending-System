import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { toast } from 'vue-sonner'

export const useCartStore = defineStore('cart', () => {
  const items = ref([])

  const totalItems = computed(() => items.value.reduce((acc, item) => acc + item.quantity, 0))

  function addItem(item, quantity = 1) {
    const existing = items.value.find(i => i.id === item.id)
    const currentQty = existing ? existing.quantity : 0
    const stock = Number(item.total_stock) // Force number

    console.log(`[Cart] Check Stock: '${item.name}' | Current: ${currentQty} | Adding: ${quantity} | Stock: ${stock} (${typeof stock})`)

    if (currentQty + quantity > stock) {
      toast.warning(`庫存不足！此器材庫存僅有 ${stock} 個，您已加入 ${currentQty} 個。`)
      return
    }

    if (existing) {
      existing.quantity += quantity
    } else {
      // Store stock in cart item just in case, though we validate against passed item
      items.value.push({ ...item, quantity, total_stock: stock })
    }
  }

  function removeItem(itemId) {
    const index = items.value.findIndex(i => i.id === itemId)
    if (index > -1) {
      items.value.splice(index, 1)
    }
  }

  function updateQuantity(itemId, newQty) {
    const item = items.value.find(i => i.id === itemId)
    if (!item) return

    const stock = Number(item.total_stock)

    if (newQty < 1) return // Min 1
    if (newQty > stock) {
        toast.warning(`庫存不足！此項目庫存上限為 ${stock}`)
        item.quantity = stock
        return
    }

    item.quantity = newQty
  }

  function clearCart() {
    items.value = []
  }

  return { items, totalItems, addItem, removeItem, updateQuantity, clearCart }
})
