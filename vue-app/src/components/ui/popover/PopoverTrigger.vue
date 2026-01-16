<script setup>
import { PopoverTrigger } from 'radix-vue'

const props = defineProps({
  asChild: { type: Boolean, default: false },
  as: { type: String, default: 'button' }
})
</script>

<template>
  <PopoverTrigger v-bind="props">
    <slot />
  </PopoverTrigger>
</template>
