
<script setup>
import { RouterLink } from 'vue-router'
import { ref, watch } from 'vue'
import { useCartStore } from '../stores/cart'
import { useAuthStore } from '../stores/auth'
import { useDark, useToggle } from '@vueuse/core'
import { ClipboardDocumentListIcon, UserIcon, ArrowPathRoundedSquareIcon, Bars3Icon, MoonIcon, SunIcon } from '@heroicons/vue/24/outline'
import { LogOut } from 'lucide-vue-next'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'

const cart = useCartStore()
const auth = useAuthStore()

const isAnimating = ref(false)

watch(() => cart.totalItems, (newVal, oldVal) => {
  if (newVal > oldVal) {
    isAnimating.value = true
    setTimeout(() => isAnimating.value = false, 200) // Trigger pop animation
  }
})

const isDark = useDark({
  selector: 'html',
  attribute: 'class',
  valueDark: 'dark',
  valueLight: '',
})
const toggleDark = useToggle(isDark)

</script>

<template>
  <nav class="bg-background border-b border-border sticky top-0 z-50">
    <div class="container mx-auto px-4 max-w-7xl">
      <div class="flex justify-between items-center h-16">
        
        <!-- Left Side: Brand + Primary Nav -->
        <div class="flex items-center gap-8">
           <!-- Mobile Menu (Hamburger) -->
           <div class="md:hidden mr-2">
             <DropdownMenu v-if="!auth.isAdmin">
               <DropdownMenuTrigger class="focus:outline-none">
                 <Bars3Icon class="w-6 h-6 text-muted-foreground" />
               </DropdownMenuTrigger>
               <DropdownMenuContent align="start" class="w-48" :side-offset="8">
                 <DropdownMenuItem>
                    <RouterLink to="/equipment" class="w-full">器材列表</RouterLink>
                 </DropdownMenuItem>
                 <DropdownMenuItem>
                    <RouterLink to="/consumables" class="w-full">耗材列表</RouterLink>
                 </DropdownMenuItem>
                 <DropdownMenuItem>
                    <RouterLink to="/meeting-rooms" class="w-full">空間預約</RouterLink>
                 </DropdownMenuItem>
               </DropdownMenuContent>
             </DropdownMenu>
           </div>

           <!-- Brand -->
           <RouterLink :to="auth.isAdmin ? '/admin/dashboard' : '/equipment'" class="flex items-center gap-2 group">
              <span class="text-lg font-bold tracking-tight text-foreground">E&S</span>
           </RouterLink>

           <!-- Primary Nav Link -->
           <div class="hidden md:flex items-center gap-6">
             <RouterLink v-if="!auth.isAdmin" to="/equipment" class="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors" active-class="text-foreground">
               器材列表
             </RouterLink>
             <RouterLink v-if="!auth.isAdmin" to="/consumables" class="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors" active-class="text-foreground">
               耗材列表
             </RouterLink>
             <RouterLink v-if="!auth.isAdmin" to="/meeting-rooms" class="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors" active-class="text-foreground">
               空間預約
             </RouterLink>
           </div>
        </div>

        <!-- Right Side: Tools & Profile -->
        <div class="flex items-center gap-4">
          
          <!-- Tool 1: My Records -->
          <RouterLink 
            v-if="!auth.isAdmin && auth.isAuthenticated" 
            to="/dashboard" 
            class="text-sm font-medium text-muted-foreground hover:text-foreground transition mr-2"
          >
            我的紀錄
          </RouterLink>

          <!-- Tool 2: Application List (Cart) -->
          <RouterLink 
            v-if="!auth.isAdmin" 
            to="/cart" 
            class="relative transition-transform duration-200 ease-out"
            :class="isAnimating ? 'scale-125 text-foreground' : 'text-muted-foreground hover:text-foreground'"
            title="申請清單"
          >
            <ClipboardDocumentListIcon class="w-5 h-5" />
            <span v-if="cart.totalItems > 0" class="absolute -top-1.5 -right-1.5 inline-flex items-center justify-center px-1 py-0.5 text-[10px] font-bold leading-none text-primary-foreground transform bg-primary rounded-full min-w-[1rem] border border-background">
              {{ cart.totalItems }}
            </span>
          </RouterLink>
          
          <!-- Tool 3: Dark Mode Toggle -->
          <button @click="toggleDark()" class="text-muted-foreground hover:text-foreground transition-colors p-1 rounded-md hover:bg-accent hover:text-accent-foreground">
             <SunIcon v-if="isDark" class="w-5 h-5" />
             <MoonIcon v-else class="w-5 h-5" />
          </button>
          
          <template v-if="auth.isAuthenticated">
             <!-- Tool 2: Admin Dashboard (Admin Only) -->


             <!-- Divider -->
             <div class="h-4 w-px bg-border mx-1"></div>

             <!-- User Profile (Avatar + Name) -->
             <!-- User Profile (Avatar + Name) -->
             <DropdownMenu>
               <DropdownMenuTrigger class="focus:outline-none select-none">
                 <div class="flex items-center gap-3 cursor-pointer group">
                     <span class="text-sm font-medium text-muted-foreground group-hover:text-foreground transition-colors hidden sm:block">{{ auth.user.name }}</span>
                     
                     <div class="w-8 h-8 rounded-full bg-secondary border border-border flex items-center justify-center text-muted-foreground group-hover:border-input group-hover:text-foreground transition-all">
                        <UserIcon class="w-4 h-4" />
                     </div>
                 </div>
               </DropdownMenuTrigger>
               <DropdownMenuContent align="end" class="w-48" :side-offset="8">
                 <DropdownMenuLabel class="font-normal">
                    <div class="flex flex-col space-y-1">
                        <p class="text-sm font-medium leading-none">{{ auth.user.name }}</p>
                        <p class="text-xs leading-none text-muted-foreground">{{ auth.user.username }}</p>
                    </div>
                 </DropdownMenuLabel>
                 <DropdownMenuSeparator />
                 
                 <template v-if="auth.isRealAdmin">
                    <DropdownMenuItem @click="auth.switchRole(auth.isAdmin ? 'USER' : 'ADMIN')" class="cursor-pointer">
                        <ArrowPathRoundedSquareIcon class="w-4 h-4 mr-2" />
                        <span>{{ auth.isAdmin ? '切換為使用者' : '切換為管理員' }}</span>
                    </DropdownMenuItem>
                    <DropdownMenuSeparator />
                 </template>

                 <DropdownMenuItem @click="auth.logout()" class="text-red-600 focus:text-red-600 focus:bg-red-50 cursor-pointer">
                   <LogOut class="w-4 h-4 mr-2" />
                   <span>登出</span>
                 </DropdownMenuItem>
               </DropdownMenuContent>
             </DropdownMenu>
          </template>
          
          <!-- Login Link (Guest) -->
          <RouterLink v-else to="/" class="flex items-center gap-1 text-sm font-medium text-muted-foreground hover:text-foreground transition">
             <span>登入</span>
          </RouterLink>
        </div>

      </div>
    </div>
  </nav>
</template>
