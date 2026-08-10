import { ref } from 'vue'
import type { Session, User } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'

export interface Profile {
  id: string
  email: string | null
  full_name: string | null
  avatar_url: string | null
}

// Module-scoped refs, not Pinia: one instance shared by every importer, created once.
export const session = ref<Session | null>(null)
export const user = ref<User | null>(null)
export const profile = ref<Profile | null>(null)
export const authReady = ref(false)

let initPromise: Promise<void> | null = null

async function loadProfile(id: string): Promise<void> {
  // Every read ends with .select() semantics; an error is logged, never swallowed into a
  // silent empty state. The row is created by the on_auth_user_created trigger.
  const { data, error } = await supabase
    .from('profiles')
    .select('id, email, full_name, avatar_url')
    .eq('id', id)
    .maybeSingle()
  if (error) {
    console.error('[auth] could not load profile:', error.message)
    return
  }
  profile.value = data
}

function apply(next: Session | null): void {
  session.value = next
  user.value = next?.user ?? null
  if (next?.user) void loadProfile(next.user.id)
  else profile.value = null
}

/**
 * Resolves once the initial session has been restored. Idempotent — the router guard awaits
 * this before deciding anything, so a hard refresh does not flash the sign-in page.
 *
 * There is no /auth/callback route and no callback component anywhere: detectSessionInUrl
 * consumes the returned code, and routing is driven by onAuthStateChange.
 */
export function initAuth(): Promise<void> {
  if (initPromise) return initPromise
  initPromise = (async () => {
    const { data, error } = await supabase.auth.getSession()
    if (error) console.error('[auth] getSession failed:', error.message)
    apply(data.session)
    supabase.auth.onAuthStateChange((_event, next) => apply(next))
    authReady.value = true
  })()
  return initPromise
}

export async function signInWithGoogle(): Promise<void> {
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      // The origin, not a callback path. Google's redirect URI is always and only the
      // Supabase callback; this is where Supabase sends the browser afterwards, and it
      // must appear in the Supabase redirect allow-list.
      redirectTo: window.location.origin,
      queryParams: { prompt: 'select_account' },
    },
  })
  if (error) throw error
}

export async function signOut(): Promise<void> {
  const { error } = await supabase.auth.signOut()
  if (error) throw error
}
