<script setup lang="ts">
import { profile, user, signOut } from '../composables/useAuth'

// Placeholder. The board, the list and the slide-over arrive in prompts 07 and 08 —
// this view exists so prompt 05's acceptance criterion ("lands on /requests") is real.
</script>

<template>
  <main class="min-h-dvh bg-brand-950 px-6 py-10 text-white">
    <div class="mx-auto max-w-3xl">
      <div class="flex items-center justify-between gap-4">
        <div class="flex items-center gap-3">
          <img
            v-if="profile?.avatar_url"
            :src="profile.avatar_url"
            alt=""
            class="size-10 rounded-full ring-1 ring-brand-700"
          />
          <div>
            <p class="text-sm font-medium">{{ profile?.full_name ?? 'Signed in' }}</p>
            <p class="text-xs text-brand-400">{{ profile?.email ?? user?.email }}</p>
          </div>
        </div>
        <button
          type="button"
          class="rounded-sm border border-brand-700 px-3 py-1.5 text-sm text-brand-200 transition hover:bg-brand-900 focus-visible:ring-3 focus-visible:ring-brand-400 focus-visible:outline-hidden"
          @click="signOut"
        >
          Sign out
        </button>
      </div>

      <p class="mt-10 text-sm text-brand-300">
        Session restored from storage. The request board lands in the next slice.
      </p>
    </div>
  </main>
</template>
