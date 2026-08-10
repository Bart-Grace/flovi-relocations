<script setup lang="ts">
import { computed } from 'vue'
import { profile, user, signOut } from '../composables/useAuth'

const displayName = computed(() => profile.value?.full_name ?? user.value?.email ?? '')
const initials = computed(() =>
  displayName.value
    .split(' ')
    .map((p) => p[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toUpperCase(),
)
</script>

<template>
  <div class="min-h-dvh bg-brand-950 text-white">
    <!-- Left rail -->
    <nav
      class="fixed inset-y-0 left-0 hidden w-14 flex-col items-center gap-1 border-r border-brand-900 bg-brand-950 py-4 sm:flex"
      aria-label="Main"
    >
      <span class="grid size-8 place-items-center rounded-(--radius-card) bg-brand-500 text-sm font-bold">
        F
      </span>
      <span class="mt-3 grid size-9 place-items-center rounded-(--radius-card) bg-brand-900 text-brand-200 ring-1 ring-brand-800">
        <svg class="size-5" viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <path d="M4 6h16M4 12h16M4 18h10" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
        </svg>
        <span class="sr-only">Requests</span>
      </span>
    </nav>

    <div class="sm:pl-14">
      <!-- Topbar -->
      <header
        class="flex items-center justify-between gap-4 border-b border-brand-900 px-5 py-3 sm:px-8"
      >
        <div class="min-w-0">
          <p class="font-mono text-[10px] tracking-[0.2em] text-brand-500 uppercase">Flovi</p>
          <h1 class="truncate text-lg font-semibold">Relocation requests</h1>
        </div>

        <div class="flex items-center gap-3">
          <div class="hidden text-right sm:block">
            <p class="text-sm font-medium">{{ displayName }}</p>
            <p class="text-xs text-brand-400">Dispatcher</p>
          </div>
          <img
            v-if="profile?.avatar_url"
            :src="profile.avatar_url"
            :alt="displayName"
            class="size-9 shrink-0 rounded-full ring-1 ring-brand-700"
            referrerpolicy="no-referrer"
          />
          <span
            v-else
            class="grid size-9 shrink-0 place-items-center rounded-full bg-brand-800 text-xs font-semibold ring-1 ring-brand-700"
          >
            {{ initials }}
          </span>
          <button
            type="button"
            class="rounded-sm border border-brand-800 px-2.5 py-1.5 text-xs text-brand-200 transition hover:bg-brand-900 focus-visible:ring-3 focus-visible:ring-brand-500 focus-visible:outline-hidden"
            @click="signOut"
          >
            Sign out
          </button>
        </div>
      </header>

      <main class="px-5 py-6 sm:px-8"><slot /></main>
    </div>
  </div>
</template>
