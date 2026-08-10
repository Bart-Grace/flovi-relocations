<script setup lang="ts">
import { toasts, dismissToast } from '../../composables/useToasts'
</script>

<template>
  <!-- Not alert(): a rejected write has to be readable without blocking the page. -->
  <div class="pointer-events-none fixed inset-x-0 bottom-0 z-50 flex flex-col items-center gap-2 p-4">
    <TransitionGroup
      enter-active-class="transition duration-200 ease-out"
      enter-from-class="translate-y-2 opacity-0"
      leave-active-class="transition duration-150 ease-in"
      leave-to-class="translate-y-1 opacity-0"
    >
      <div
        v-for="toast in toasts"
        :key="toast.id"
        class="pointer-events-auto flex max-w-md items-start gap-3 rounded-(--radius-card) border px-4 py-3 text-sm shadow-sm"
        :class="
          toast.kind === 'error'
            ? 'border-red-800 bg-red-950 text-red-100'
            : 'border-brand-700 bg-brand-900 text-brand-50'
        "
        role="status"
      >
        <span class="mt-1.5 size-1.5 shrink-0 rounded-full"
          :class="toast.kind === 'error' ? 'bg-red-400' : 'bg-emerald-400'" />
        <span class="min-w-0 flex-1">{{ toast.message }}</span>
        <button
          type="button"
          class="shrink-0 text-xs opacity-60 transition hover:opacity-100 focus-visible:ring-3 focus-visible:ring-brand-400 focus-visible:outline-hidden"
          @click="dismissToast(toast.id)"
        >
          Dismiss
        </button>
      </div>
    </TransitionGroup>
  </div>
</template>
