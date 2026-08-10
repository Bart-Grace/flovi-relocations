<script setup lang="ts">
import { watch } from 'vue'
import { useRouter } from 'vue-router'
import { missingEnv } from './lib/supabase'
import { session } from './composables/useAuth'

const router = useRouter()

// Routing is driven by onAuthStateChange, not by a callback route. Signing in or out
// anywhere in the app moves the user; the guard in router/index.ts handles direct hits.
watch(session, (next, prev) => {
  if (next && !prev) void router.replace({ name: 'requests' })
  if (!next && prev) void router.replace({ name: 'signin' })
})
</script>

<template>
  <!-- Boot guard first: if configuration is missing, name the variable, never render blank. -->
  <div
    v-if="missingEnv.length"
    class="flex min-h-dvh items-center justify-center bg-red-50 p-6 dark:bg-red-950"
  >
    <div
      class="max-w-md rounded-(--radius-card) border border-red-300 bg-white p-6 dark:border-red-800 dark:bg-red-900"
    >
      <h1 class="text-base font-semibold text-red-900 dark:text-red-100">Configuration missing</h1>
      <p class="mt-2 text-sm text-red-800 dark:text-red-200">
        The build is missing
        <template v-for="(name, i) in missingEnv" :key="name"
          ><code class="rounded-sm bg-red-100 px-1 py-0.5 font-mono text-xs dark:bg-red-800">{{
            name
          }}</code
          ><span v-if="i < missingEnv.length - 1">, </span></template
        >. Set it as a Vercel project environment variable, then
        <strong>redeploy</strong> — Vite inlines these at build time, so changing them without a
        rebuild has no effect.
      </p>
    </div>
  </div>

  <RouterView v-else />
</template>
