
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
      <RouterView />
    </main>
    <Toaster position="top-center" :duration="2000" />
  </div>
</template>
