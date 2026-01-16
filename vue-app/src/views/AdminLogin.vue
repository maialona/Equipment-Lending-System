
<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'

const password = ref('')
const error = ref('')
const router = useRouter()

// In a real app we'd use Supabase Auth
// For this MVP refactor, we simulate the "Shared Password" from the original requirement
const ADMIN_PASSWORD = 'admin' 

function login() {
  if (password.value === ADMIN_PASSWORD) {
    localStorage.setItem('admin_token', 'true')
    router.push('/admin/dashboard')
  } else {
    error.value = '密碼錯誤'
  }
}
</script>

<template>
  <div class="flex items-center justify-center min-h-[60vh]">
    <div class="bg-white p-8 rounded-xl shadow-lg border border-gray-100 w-full max-w-sm">
      <h2 class="text-2xl font-bold text-center mb-6 text-gray-800">管理員登入</h2>
      
      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">管理密碼</label>
          <input 
            v-model="password" 
            @keyup.enter="login"
            type="password" 
            class="w-full border-gray-300 rounded-lg shadow-sm focus:ring-blue-500 focus:border-blue-500 p-2.5 border"
            placeholder="請輸入密碼 (admin)"
          >
        </div>
        
        <div v-if="error" class="text-red-500 text-sm text-center font-medium">{{ error }}</div>

        <button 
          @click="login" 
          class="w-full bg-gray-900 text-white py-2.5 rounded-lg font-bold hover:bg-gray-800 transition"
        >
          登入系統
        </button>
      </div>
    </div>
  </div>
</template>
