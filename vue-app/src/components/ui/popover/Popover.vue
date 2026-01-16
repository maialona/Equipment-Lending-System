<script setup>
import { PopoverRoot, useForwardPropsEmits } from 'radix-vue'

const props = defineProps(['defaultOpen', 'open', 'modal'])
const emits = defineEmits(['update:open'])

const forwarded = useForwardPropsEmits(props, emits)
</script>

<template>
  <PopoverRoot v-bind="forwarded">
    <slot />
  </PopoverRoot>
</template>
