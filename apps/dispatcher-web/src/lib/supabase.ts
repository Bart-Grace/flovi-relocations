import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY

/**
 * Boot guard. Vite inlines VITE_* at build time, so a missing variable produces a bundle
 * containing `undefined` and a blank white page with `supabaseUrl is required` in the console.
 * We surface the missing name instead — a blank page is a failure, not a diagnosis.
 */
export const missingEnv: string[] = [
  url ? null : 'VITE_SUPABASE_URL',
  key ? null : 'VITE_SUPABASE_PUBLISHABLE_KEY',
].filter((v): v is string => v !== null)

/**
 * A plain module const. Never ref(), never reactive(), never inside a store — wrapping the
 * client in Vue reactivity makes the realtime client throw
 * "TypeError: Cannot read private member" from behind a Proxy.
 */
export const supabase = createClient(url ?? 'http://invalid.local', key ?? 'missing', {
  auth: {
    flowType: 'pkce',
    detectSessionInUrl: true,
    persistSession: true,
    autoRefreshToken: true,
  },
})
