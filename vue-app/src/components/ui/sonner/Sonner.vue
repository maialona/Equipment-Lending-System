<script setup>
import { Toaster as Sonner } from 'vue-sonner'

const props = defineProps({
  ...Sonner.props,
})
</script>

<template>
  <Sonner
    class="toaster group"
    v-bind="props"
    :toast-options="{
      class: 'group toast group-[.toaster]:bg-zinc-950 group-[.toaster]:text-zinc-50 group-[.toaster]:border-zinc-800 group-[.toaster]:shadow-lg',
      descriptionClass: 'group-[.toast]:text-zinc-400',
      actionButtonClass: 'group-[.toast]:bg-zinc-50 group-[.toast]:text-zinc-900',
      cancelButtonClass: 'group-[.toast]:bg-zinc-800 group-[.toast]:text-zinc-400',
    }"
  />
</template>
