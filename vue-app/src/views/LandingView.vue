<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import LoginHero from '../components/LoginHero.vue'
import { 
  BuildingLibraryIcon,
  UserIcon,
  LockClosedIcon,
  ArrowRightIcon
} from '@heroicons/vue/24/outline'

const router = useRouter()
const authStore = useAuthStore()


const username = ref('')
const password = ref('')
const error = ref('')
const loading = ref(false)

async function handleLogin() {
    loading.value = true
    error.value = ''
    
    try {
        const user = await authStore.login(username.value, password.value)
        // Check currentRole from store (which is already set to ADMIN if one of the roles is ADMIN)
        if (authStore.currentRole === 'ADMIN') {
            router.push('/admin/dashboard')
        } else {
            router.push('/equipment')
        }
    } catch (e) {
        error.value = e.message
    } finally {
        loading.value = false
    }
}
</script>

<template>
  <div class="min-h-[calc(100vh-64px)] flex items-center justify-center bg-muted/20 p-4">
    <!-- Main Card -->
    <div class="w-full max-w-4xl bg-card rounded-lg border border-border overflow-hidden flex shadow-xl shadow-black/5 md:min-h-[500px]">
      
      <!-- Left: Brand (Simplified) -->
      <div class="hidden md:flex w-5/12 bg-zinc-950 p-12 flex-col text-white relative overflow-hidden">
         <!-- Dot Grid Texture -->
         <div class="absolute inset-0 opacity-[0.15] bg-[radial-gradient(#71717a_1px,transparent_1px)] [background-size:24px_24px] z-0"></div>
         
         <!-- 3D Illustration (Real CSS Component) -->
         <div class="absolute inset-0 flex items-center justify-center z-0 perspective-container">
             <LoginHero />
             <!-- Gradient Overlay for Text Readability -->
             <div class="absolute inset-0 bg-gradient-to-b from-zinc-950/40 via-transparent to-zinc-950/80 pointer-events-none"></div>
         </div>
         
         <!-- Spacer to push content down -->
         <div class="flex-1"></div>

         <!-- Brand & Slogan Group -->
         <div class="relative z-10 mb-12">
            <h1 class="text-4xl font-serif font-bold tracking-tight mb-4 animate-fade-in-up delay-500">E&S</h1>
            <blockquote class="text-2xl font-serif italic font-medium leading-relaxed opacity-90 max-w-sm animate-fade-in-up delay-700">
              "The place to simplify your workday."
            </blockquote>
         </div>

         <!-- Footer -->
         <div class="relative z-10 text-xs text-white/40 font-medium tracking-wide animate-fade-in-up delay-1000">
            &copy; 2026 E&S. All rights reserved.
         </div>
      </div>

      <!-- Right: Login Form -->
      <div class="w-full md:w-7/12 p-8 md:p-16 flex flex-col justify-center bg-card relative">
        <div class="max-w-xs mx-auto w-full">
            <div class="mb-10">
              <h2 class="text-xl font-bold text-foreground">歡迎回來</h2>
              <p class="text-sm text-muted-foreground mt-1">請輸入您的帳號密碼以登入</p>
            </div>

            <!-- Error -->
            <div v-if="error" class="mb-6 bg-destructive/10 text-destructive px-3 py-2.5 rounded-md text-sm border border-destructive/20 flex items-center gap-2">
               <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-4 h-4 shrink-0">
                 <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
               </svg>
               {{ error }}
            </div>

            <div class="space-y-5">
              <div class="space-y-1.5">
                 <label class="text-xs font-bold text-foreground">帳號</label>
                 <input 
                    v-model="username" 
                    @keyup.enter="handleLogin"
                    type="text" 
                    class="block w-full rounded-md border border-input bg-background shadow-sm focus:border-ring focus:ring-2 focus:ring-ring/20 py-2.5 px-3 transition-all text-sm placeholder:text-muted-foreground text-foreground"
                    placeholder=""
                 >
              </div>

              <div class="space-y-1.5">
                 <label class="text-xs font-bold text-zinc-900">密碼</label>
                 <input 
                    v-model="password" 
                    @keyup.enter="handleLogin"
                    type="password" 
                    class="block w-full rounded-md border border-zinc-200 bg-white shadow-sm focus:border-zinc-900 focus:ring-2 focus:ring-zinc-900 focus:ring-opacity-20 py-2.5 px-3 transition-all text-sm placeholder:text-zinc-400"
                 >
              </div>

              <button 
                @click="handleLogin" 
                :disabled="loading"
                class="w-full flex justify-center py-2.5 px-4 border border-transparent rounded-md shadow-sm text-sm font-bold text-white bg-zinc-900 hover:bg-zinc-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-zinc-900 disabled:opacity-70 transition-all mt-8"
              >
                <span v-if="loading">登入中...</span>
                <span v-else>登入</span>
              </button>
            </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.animate-fade-in-up {
  opacity: 0; /* Hidden by default */
  animation: fadeInUp 0.8s cubic-bezier(0.16, 1, 0.3, 1) forwards;
}

.delay-500 { animation-delay: 500ms; }
.delay-700 { animation-delay: 700ms; }
.delay-1000 { animation-delay: 1000ms; }
</style>

<style scoped>
.animate-blob {
  animation: blob 7s infinite;
}
.animation-delay-2000 {
  animation-delay: 2s;
}
@keyframes blob {
  0% { transform: translate(0px, 0px) scale(1); }
  33% { transform: translate(30px, -50px) scale(1.1); }
  66% { transform: translate(-20px, 20px) scale(0.9); }
  100% { transform: translate(0px, 0px) scale(1); }
}

/* Slogan Entrance Animation */
@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translate3d(0, 20px, 0);
  }
  to {
    opacity: 1;
    transform: translate3d(0, 0, 0);
  }
}
.animate-fade-in-up {
  animation: fadeInUp 0.8s ease-out 0.5s forwards; /* 0.5s delay */
  opacity: 0; /* Maintain invisible until animation starts */
}
</style>
