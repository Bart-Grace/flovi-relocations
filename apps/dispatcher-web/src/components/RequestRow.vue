<script setup lang="ts">
import { computed } from 'vue'
import StatusPill from './StatusPill.vue'
import { driverProfiles, type RelocationRequest, type RequestStatus } from '../composables/useRequests'

// Full class strings so Tailwind v4's source scan finds them.
const ACCENT: Record<RequestStatus, string> = {
  open: '',
  booked: 'bg-blue-400',
  in_transit: 'bg-indigo-400',
  completed: 'bg-emerald-400',
  cancelled: 'bg-zinc-500',
}

const props = defineProps<{ request: RelocationRequest }>()
defineEmits<{ open: [RelocationRequest] }>()

const driver = computed(() =>
  props.request.driver_id ? (driverProfiles.value[props.request.driver_id] ?? null) : null,
)

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
    <!-- Grid template duplicated verbatim from RequestList.vue's header. Keep them in sync. -->
    <button
      type="button"
      class="relative grid w-full grid-cols-[1fr_auto] items-center gap-x-4 gap-y-2 border-b border-brand-900 py-4 pr-5 pl-6 text-left transition hover:bg-brand-900/40 focus-visible:ring-3 focus-visible:ring-brand-500 focus-visible:outline-hidden sm:grid-cols-[minmax(0,1fr)_6rem_7rem_6.5rem]"
      @click="$emit('open', request)"
    >
      <!-- A row that is no longer open earns a left accent in its status colour. The pill
           alone sits ~800px from the route; during the money shot the flip has to be
           visible from across the room, not findable by reading. -->
      <span
        v-if="request.status !== 'open'"
        class="absolute inset-y-0 left-0 w-1"
        :class="ACCENT[request.status]"
        aria-hidden="true"
      />
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
        <!-- The money shot: who took it, with their real Google face and name. -->
        <span v-if="driver" class="mt-1 flex items-center gap-1.5">
          <img
            v-if="driver.avatar_url"
            :src="driver.avatar_url"
            alt=""
            class="size-4 rounded-full ring-1 ring-brand-700"
            referrerpolicy="no-referrer"
          />
          <span class="truncate text-xs text-brand-300">{{ driver.full_name }}</span>
        </span>
        <span v-else-if="request.notes" class="mt-0.5 block truncate text-xs text-brand-400">
          {{ request.notes }}
        </span>
      </span>

      <span class="hidden text-sm text-brand-300 tabular-nums sm:block">{{ pickup }}</span>
      <span class="hidden text-right text-sm text-brand-300 tabular-nums sm:block">{{ price ?? '—' }}</span>

      <!-- justify-self-start: a grid item stretches by default, and a fixed-width status
           column turned the pill into a wide box instead of a badge. -->
      <StatusPill :status="request.status" class="justify-self-start" />
    </button>
  </li>
</template>
