<script setup lang="ts">
import RequestRow from './RequestRow.vue'
import EmptyState from './EmptyState.vue'
import { requests, loading, loadError } from '../composables/useRequests'
import type { RelocationRequest } from '../composables/useRequests'

defineEmits<{ open: [RelocationRequest]; create: [] }>()
</script>

<template>
  <section
    class="overflow-hidden rounded-(--radius-card) border border-brand-800 bg-brand-900/40"
  >
    <header
      class="hidden grid-cols-[minmax(0,1fr)_7rem_6rem_5.5rem] gap-4 border-b border-brand-800 px-5 py-2.5 text-xs font-medium tracking-wide text-brand-400 uppercase sm:grid"
    >
      <span>Route</span>
      <span>Pickup</span>
      <span>Price</span>
      <span>Status</span>
    </header>

    <!-- A skeleton, never the literal string "Loading...". -->
    <div v-if="loading && !requests.length" class="divide-y divide-brand-900">
      <div v-for="n in 3" :key="n" class="flex items-center gap-4 px-5 py-4">
        <div class="h-3 flex-1 animate-pulse rounded-full bg-brand-800" />
        <div class="h-5 w-20 animate-pulse rounded-full bg-brand-800" />
      </div>
    </div>

    <p v-else-if="loadError" class="px-5 py-8 text-sm text-red-300">
      Could not load requests: {{ loadError }}
    </p>

    <EmptyState v-else-if="!requests.length" @cta="$emit('create')" />

    <ul v-else>
      <RequestRow
        v-for="request in requests"
        :key="request.id"
        :request="request"
        @open="$emit('open', $event)"
      />
    </ul>
  </section>
</template>
