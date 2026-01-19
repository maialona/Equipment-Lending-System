
<script setup>
import { RouterView, useRoute } from 'vue-router'
import Navbar from './components/Navbar.vue'
import { Toaster } from '@/components/ui/sonner'

const route = useRoute()
</script>

<template>
  <div class="min-h-screen bg-background text-foreground font-sans">
    <Navbar v-if="route.path !== '/'" />
    <main class="container mx-auto px-4 py-6 max-w-5xl">
      <RouterView v-slot="{ Component }">
        <Transition name="fade" mode="out-in">
          <component :is="Component" />
        </Transition>
      </RouterView>
    </main>
    <Toaster position="top-center" :duration="2000" />
  </div>
</template>

<style>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
