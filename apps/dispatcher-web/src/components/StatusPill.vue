<script setup lang="ts">
import type { RequestStatus } from '../composables/useRequests'

defineProps<{ status: RequestStatus }>()

// A dot plus a label. Never bare status text — this is what the camera is pointed at
// during the money shot. Full class strings so Tailwind v4's source scan finds them.
const STYLES: Record<RequestStatus, { label: string; dot: string; text: string; ring: string }> = {
  open: { label: 'Open', dot: 'bg-amber-400', text: 'text-amber-200', ring: 'ring-amber-400/25' },
  booked: { label: 'Booked', dot: 'bg-blue-400', text: 'text-blue-200', ring: 'ring-blue-400/25' },
  in_transit: {
    label: 'In transit',
    dot: 'bg-indigo-400',
    text: 'text-indigo-200',
    ring: 'ring-indigo-400/25',
  },
  completed: {
    label: 'Completed',
    dot: 'bg-emerald-400',
    text: 'text-emerald-200',
    ring: 'ring-emerald-400/25',
  },
  cancelled: {
    label: 'Cancelled',
    dot: 'bg-zinc-400',
    text: 'text-zinc-300',
    ring: 'ring-zinc-400/25',
  },
}
</script>

<template>
  <span
    class="inline-flex shrink-0 items-center gap-1.5 rounded-full bg-white/5 px-2.5 py-1 text-xs font-medium ring-1 ring-inset"
    :class="[STYLES[status].text, STYLES[status].ring]"
  >
    <span class="size-1.5 rounded-full" :class="STYLES[status].dot" aria-hidden="true" />
    {{ STYLES[status].label }}
  </span>
</template>
