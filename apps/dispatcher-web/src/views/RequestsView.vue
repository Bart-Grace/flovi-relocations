<script setup lang="ts">
import { onMounted, ref } from 'vue'
import AppShell from '../components/AppShell.vue'
import RequestList from '../components/RequestList.vue'
import RequestSlideOver from '../components/RequestSlideOver.vue'
import ToastStack from '../components/ui/ToastStack.vue'
import {
  fetchRequests,
  requests,
  ensureDriverProfile,
  type RelocationRequest,
} from '../composables/useRequests'
import { useRequestsRealtime } from '../composables/useRealtime'

onMounted(async () => {
  await fetchRequests()
  // Rows that were already booked before this page loaded still need a face and a name.
  await Promise.all(
    [...new Set(requests.value.map((r) => r.driver_id).filter((id): id is string => !!id))].map(
      ensureDriverProfile,
    ),
  )
})

// Mounted here, never at module top level: the channel must not exist before the session does.
useRequestsRealtime()

const panelOpen = ref(false)
const editing = ref<RelocationRequest | null>(null)

function openCreate() {
  editing.value = null
  panelOpen.value = true
}

function openEdit(request: RelocationRequest) {
  editing.value = request
  panelOpen.value = true
}
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
          @click="openCreate"
        >
          New request
        </button>
      </div>

      <RequestList @create="openCreate" @open="openEdit" />
    </div>

    <RequestSlideOver :open="panelOpen" :request="editing" @close="panelOpen = false" />
    <ToastStack />
  </AppShell>
</template>
