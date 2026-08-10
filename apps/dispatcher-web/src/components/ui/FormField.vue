<script setup lang="ts">
defineProps<{ label: string; hint?: string; required?: boolean }>()
</script>

<template>
  <label class="block">
    <span class="mb-1.5 flex items-baseline gap-1.5">
      <span class="text-sm font-medium text-brand-100">{{ label }}</span>
      <span v-if="required" class="text-xs text-brand-400">required</span>
      <span v-else-if="hint" class="text-xs text-brand-500">{{ hint }}</span>
    </span>
    <slot />
  </label>
</template>
