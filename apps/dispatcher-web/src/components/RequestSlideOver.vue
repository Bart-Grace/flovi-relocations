<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import FormField from './ui/FormField.vue'
import StatusPill from './StatusPill.vue'
import {
  createRequest,
  updateRequest,
  cancelRequest,
  type RelocationRequest,
  type RequestDraft,
} from '../composables/useRequests'
import { pushToast } from '../composables/useToasts'

const props = defineProps<{ open: boolean; request: RelocationRequest | null }>()
const emit = defineEmits<{ close: [] }>()

const INPUT =
  'w-full rounded-(--radius-card) border border-brand-700 bg-brand-950 px-3 py-2 text-sm text-white placeholder:text-brand-600 focus-visible:border-brand-500 focus-visible:ring-3 focus-visible:ring-brand-500/40 focus-visible:outline-hidden'

const origin = ref('')
const destination = ref('')
const pickupDate = ref('')
const notes = ref('')
const vehicleType = ref('')
// string | number, deliberately. Vue 3 applies the `.number` modifier AUTOMATICALLY to
// <input type="number">, so this ref holds a number as soon as the user types — while
// `ref('')` would infer Ref<string> and TypeScript would happily let us call .replace on it.
// That exact hole shipped once: "S.value.replace is not a function", caught only in the browser.
const priceEuros = ref<string | number>('')
const busy = ref(false)

// One component, two modes. Edit prefills from the row passed in.
const isEdit = computed(() => props.request !== null)

watch(
  () => [props.open, props.request] as const,
  ([open, request]) => {
    if (!open) return
    origin.value = request?.origin ?? ''
    destination.value = request?.destination ?? ''
    pickupDate.value = request?.pickup_date ?? ''
    notes.value = request?.notes ?? ''
    vehicleType.value = request?.vehicle_type ?? ''
    priceEuros.value = request && request.price_cents > 0 ? String(request.price_cents / 100) : ''
  },
  { immediate: true },
)

function draft(): RequestDraft {
  // String() first: the value may already be a number (see the ref's declaration).
  const euros = Number.parseFloat(String(priceEuros.value).replace(',', '.'))
  return {
    origin: origin.value.trim(),
    destination: destination.value.trim(),
    pickup_date: pickupDate.value,
    notes: notes.value.trim() || null,
    vehicle_type: vehicleType.value.trim() || null,
    price_cents: Number.isFinite(euros) ? Math.round(euros * 100) : 0,
  }
}

async function onSubmit() {
  busy.value = true
  try {
    if (props.request) {
      await updateRequest(props.request.id, draft())
      pushToast('success', 'Request updated.')
    } else {
      const row = await createRequest(draft())
      pushToast('success', `Created ${row.origin} → ${row.destination}.`)
    }
    emit('close')
  } catch (e) {
    // The panel stays open on failure — a rejected write must not look like a save.
    pushToast('error', e instanceof Error ? e.message : String(e))
  } finally {
    busy.value = false
  }
}

async function onCancelRequest() {
  if (!props.request) return
  busy.value = true
  try {
    await cancelRequest(props.request.id)
    pushToast('success', 'Request cancelled.')
    emit('close')
  } catch (e) {
    pushToast('error', e instanceof Error ? e.message : String(e))
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <Transition
    enter-active-class="transition duration-200 ease-out"
    enter-from-class="opacity-0"
    leave-active-class="transition duration-150 ease-in"
    leave-to-class="opacity-0"
  >
    <div v-if="open" class="fixed inset-0 z-40 bg-black/50" @click="emit('close')" />
  </Transition>

  <Transition
    enter-active-class="transition duration-200 ease-out"
    enter-from-class="translate-x-full"
    leave-active-class="transition duration-150 ease-in"
    leave-to-class="translate-x-full"
  >
    <aside
      v-if="open"
      class="fixed inset-y-0 right-0 z-40 flex w-full max-w-md flex-col border-l border-brand-800 bg-brand-950"
      role="dialog"
      aria-modal="true"
    >
      <header class="flex items-start justify-between gap-4 border-b border-brand-900 px-5 py-4">
        <div>
          <h2 class="text-base font-semibold text-white">
            {{ isEdit ? 'Edit request' : 'New request' }}
          </h2>
          <StatusPill v-if="request" :status="request.status" class="mt-2" />
        </div>
        <button
          type="button"
          class="rounded-sm border border-brand-800 px-2 py-1 text-xs text-brand-300 transition hover:bg-brand-900 focus-visible:ring-3 focus-visible:ring-brand-500 focus-visible:outline-hidden"
          @click="emit('close')"
        >
          Close
        </button>
      </header>

      <form class="flex min-h-0 flex-1 flex-col" @submit.prevent="onSubmit">
        <div class="flex-1 space-y-4 overflow-y-auto px-5 py-5">
          <FormField label="Origin" required>
            <input v-model="origin" :class="INPUT" required placeholder="Warsaw" />
          </FormField>

          <FormField label="Destination" required>
            <input v-model="destination" :class="INPUT" required placeholder="Berlin" />
          </FormField>

          <!-- A date input bound to the date column, never free text. -->
          <FormField label="Pickup date" required>
            <input v-model="pickupDate" type="date" :class="INPUT" required />
          </FormField>

          <FormField label="Vehicle type" hint="optional">
            <input v-model="vehicleType" :class="INPUT" placeholder="Van, 3.5t" />
          </FormField>

          <FormField label="Price" hint="EUR, optional">
            <input v-model="priceEuros" type="number" min="0" step="0.01" :class="INPUT" placeholder="0.00" />
          </FormField>

          <FormField label="Notes" hint="optional">
            <textarea v-model="notes" rows="3" :class="INPUT" placeholder="Two-seater, ground floor" />
          </FormField>
        </div>

        <footer class="flex items-center gap-3 border-t border-brand-900 px-5 py-4">
          <button
            type="submit"
            :disabled="busy"
            class="rounded-(--radius-card) bg-brand-500 px-4 py-2 text-sm font-medium text-white transition hover:bg-brand-400 focus-visible:ring-3 focus-visible:ring-brand-400 focus-visible:outline-hidden disabled:opacity-60"
          >
            {{ busy ? 'Saving…' : isEdit ? 'Save changes' : 'Create request' }}
          </button>

          <!-- Cancelling is a status transition. There is no delete anywhere in this app. -->
          <button
            v-if="isEdit && request?.status !== 'cancelled'"
            type="button"
            :disabled="busy"
            class="ml-auto rounded-(--radius-card) border border-brand-800 px-3 py-2 text-sm text-brand-300 transition hover:bg-brand-900 hover:text-white focus-visible:ring-3 focus-visible:ring-brand-500 focus-visible:outline-hidden disabled:opacity-60"
            @click="onCancelRequest"
          >
            Cancel request
          </button>
        </footer>
      </form>
    </aside>
  </Transition>
</template>
