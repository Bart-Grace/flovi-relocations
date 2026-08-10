<script setup lang="ts">
import { missingEnv } from './lib/supabase'
</script>

<template>
  <!-- Boot guard first: if configuration is missing, say which variable, never render blank. -->
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

  <div v-else class="flex min-h-dvh items-center justify-center bg-brand-950 p-6">
    <div class="text-center">
      <p class="font-mono text-xs tracking-widest text-brand-400 uppercase">Flovi</p>
      <h1 class="mt-3 text-2xl font-semibold text-white">Dispatcher</h1>
      <p class="mt-2 text-sm text-brand-300">Relocation requests · scaffold</p>
    </div>
  </div>
</template>
