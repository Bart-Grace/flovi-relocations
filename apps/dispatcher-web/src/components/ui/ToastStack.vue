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
        class="pointer-events-auto flex max-w-md items-center gap-3 rounded-full border py-2.5 pr-3 pl-3 text-sm shadow-lg ring-1 ring-inset"
        :class="
          toast.kind === 'error'
            ? 'border-red-800/60 bg-red-950 text-red-100 ring-red-400/20'
            : 'border-emerald-500/40 bg-emerald-950 text-emerald-50 ring-emerald-400/25'
        "
        role="status"
      >
        <span
          class="grid size-5 shrink-0 place-items-center rounded-full"
          :class="toast.kind === 'error' ? 'bg-red-500/20' : 'bg-emerald-400/20'"
          aria-hidden="true"
        >
          <svg
            v-if="toast.kind === 'success'"
            class="size-3 text-emerald-300"
            viewBox="0 0 12 12"
            fill="none"
          >
            <path
              d="M2.5 6.3 4.7 8.5 9.5 3.7"
              stroke="currentColor"
              stroke-width="1.8"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
          <svg v-else class="size-3 text-red-300" viewBox="0 0 12 12" fill="none">
            <path
              d="M6 3v3.6M6 8.8h.01"
              stroke="currentColor"
              stroke-width="1.8"
              stroke-linecap="round"
            />
          </svg>
        </span>
        <span class="min-w-0 flex-1 pr-1">{{ toast.message }}</span>
        <button
          type="button"
          class="shrink-0 rounded-full px-2 py-1 text-xs opacity-60 transition hover:bg-white/10 hover:opacity-100 focus-visible:ring-3 focus-visible:ring-emerald-400/50 focus-visible:outline-hidden"
          @click="dismissToast(toast.id)"
        >
          Dismiss
        </button>
      </div>
    </TransitionGroup>
  </div>
</template>
