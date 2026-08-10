<script setup lang="ts">
defineEmits<{ cta: [] }>()
</script>

<template>
  <div class="flex flex-col items-center px-6 py-20 text-center">
    <span
      class="grid size-12 place-items-center rounded-(--radius-card) bg-brand-900 ring-1 ring-brand-800"
    >
      <!-- An icon, not an emoji. -->
      <svg class="size-6 text-brand-400" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <path
          d="M3 7h11v8H3zM14 10h4l3 3v2h-7z"
          stroke="currentColor"
          stroke-width="1.5"
          stroke-linejoin="round"
        />
        <circle cx="7" cy="17" r="1.8" stroke="currentColor" stroke-width="1.5" />
        <circle cx="17.5" cy="17" r="1.8" stroke="currentColor" stroke-width="1.5" />
      </svg>
    </span>

    <p class="mt-4 text-sm text-brand-300">
      No relocation requests yet — create the first one and drivers will see it instantly.
    </p>

    <button
      type="button"
      class="mt-5 rounded-(--radius-card) bg-brand-500 px-4 py-2 text-sm font-medium text-white transition hover:bg-brand-400 focus-visible:ring-3 focus-visible:ring-brand-400 focus-visible:outline-hidden"
      @click="$emit('cta')"
    >
      New request
    </button>
  </div>
</template>
