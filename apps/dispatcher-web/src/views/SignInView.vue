<script setup lang="ts">
import { ref } from 'vue'
import { signInWithGoogle } from '../composables/useAuth'

const busy = ref(false)
const error = ref<string | null>(null)

async function onSignIn() {
  busy.value = true
  error.value = null
  try {
    await signInWithGoogle()
    // No navigation here: the browser leaves for Google. On return, detectSessionInUrl
    // consumes the code and onAuthStateChange drives the redirect.
  } catch (e) {
    error.value = e instanceof Error ? e.message : String(e)
    busy.value = false
  }
}
</script>

<template>
  <main class="grid min-h-dvh place-items-center bg-brand-950 px-6">
    <div class="w-full max-w-sm">
      <p class="font-mono text-xs tracking-[0.2em] text-brand-400 uppercase">Flovi</p>
      <h1 class="mt-3 text-3xl font-semibold text-white">Dispatcher</h1>
      <p class="mt-2 text-sm leading-relaxed text-brand-300">
        Create relocation requests and follow them from open to delivered, live.
      </p>

      <button
        type="button"
        :disabled="busy"
        class="mt-8 flex w-full items-center justify-center gap-3 rounded-(--radius-card) border border-brand-700 bg-white px-4 py-3 text-sm font-medium text-brand-950 transition hover:bg-brand-50 focus-visible:ring-3 focus-visible:ring-brand-400 focus-visible:outline-hidden disabled:opacity-60"
        @click="onSignIn"
      >
        <svg class="size-5 shrink-0" viewBox="0 0 24 24" aria-hidden="true">
          <path
            fill="#4285F4"
            d="M23.5 12.3c0-.8-.1-1.6-.2-2.3H12v4.5h6.5a5.6 5.6 0 0 1-2.4 3.6v3h3.9c2.3-2.1 3.5-5.2 3.5-8.8Z"
          />
          <path
            fill="#34A853"
            d="M12 24c3.2 0 5.9-1.1 7.9-2.9l-3.9-3c-1.1.7-2.4 1.2-4 1.2-3.1 0-5.7-2.1-6.6-4.9H1.4v3.1A12 12 0 0 0 12 24Z"
          />
          <path fill="#FBBC05" d="M5.4 14.4a7.2 7.2 0 0 1 0-4.6V6.7H1.4a12 12 0 0 0 0 10.8l4-3.1Z" />
          <path
            fill="#EA4335"
            d="M12 4.8c1.8 0 3.3.6 4.6 1.8l3.4-3.4C17.9 1.2 15.2 0 12 0A12 12 0 0 0 1.4 6.7l4 3.1C6.3 6.9 8.9 4.8 12 4.8Z"
          />
        </svg>
        {{ busy ? 'Opening Google…' : 'Continue with Google' }}
      </button>

      <p v-if="error" class="mt-4 rounded-sm bg-red-950 px-3 py-2 text-sm text-red-200">
        {{ error }}
      </p>
    </div>
  </main>
</template>
