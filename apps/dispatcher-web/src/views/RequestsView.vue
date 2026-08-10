<script setup lang="ts">
import { onMounted } from 'vue'
import AppShell from '../components/AppShell.vue'
import RequestList from '../components/RequestList.vue'
import { fetchRequests, requests } from '../composables/useRequests'

onMounted(fetchRequests)

// The slide-over arrives in prompt 08; these handlers are its seam.
function onCreate() {}
function onOpen() {}
</script>

<template>
  <AppShell>
    <div class="mx-auto max-w-5xl">
      <div class="mb-4 flex items-center justify-between gap-4">
        <p class="text-sm text-brand-400">
          {{ requests.length }} {{ requests.length === 1 ? 'request' : 'requests' }}
        </p>
        <button
          type="button"
          class="rounded-(--radius-card) bg-brand-500 px-4 py-2 text-sm font-medium text-white transition hover:bg-brand-400 focus-visible:ring-3 focus-visible:ring-brand-400 focus-visible:outline-hidden"
          @click="onCreate"
        >
          New request
        </button>
      </div>

      <RequestList @create="onCreate" @open="onOpen" />
    </div>
  </AppShell>
</template>
