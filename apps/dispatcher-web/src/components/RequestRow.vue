<script setup lang="ts">
import { computed } from 'vue'
import StatusPill from './StatusPill.vue'
import type { RelocationRequest } from '../composables/useRequests'

const props = defineProps<{ request: RelocationRequest }>()
defineEmits<{ open: [RelocationRequest] }>()

const pickup = computed(() =>
  new Date(props.request.pickup_date + 'T00:00:00').toLocaleDateString(undefined, {
    day: 'numeric',
    month: 'short',
  }),
)

const price = computed(() =>
  props.request.price_cents > 0
    ? new Intl.NumberFormat(undefined, { style: 'currency', currency: 'EUR' }).format(
        props.request.price_cents / 100,
      )
    : null,
)
</script>

<template>
  <li>
    <button
      type="button"
      class="grid w-full grid-cols-[1fr_auto] items-center gap-x-4 gap-y-2 border-b border-brand-900 px-5 py-4 text-left transition hover:bg-brand-900/40 focus-visible:ring-3 focus-visible:ring-brand-500 focus-visible:outline-hidden sm:grid-cols-[minmax(0,1fr)_7rem_6rem_auto]"
      @click="$emit('open', request)"
    >
      <span class="min-w-0">
        <span class="flex items-center gap-2 text-sm font-medium text-white">
          <span class="truncate">{{ request.origin }}</span>
          <svg class="size-4 shrink-0 text-brand-500" viewBox="0 0 16 16" aria-hidden="true">
            <path
              d="M2 8h10M9 5l3 3-3 3"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
          <span class="truncate">{{ request.destination }}</span>
        </span>
        <span v-if="request.notes" class="mt-0.5 block truncate text-xs text-brand-400">
          {{ request.notes }}
        </span>
      </span>

      <span class="hidden text-sm text-brand-300 tabular-nums sm:block">{{ pickup }}</span>
      <span class="hidden text-sm text-brand-300 tabular-nums sm:block">{{ price ?? '—' }}</span>

      <StatusPill :status="request.status" />
    </button>
  </li>
</template>
