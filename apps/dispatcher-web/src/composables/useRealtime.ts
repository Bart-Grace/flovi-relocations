import { onMounted, onUnmounted } from 'vue'
import type { RealtimeChannel, RealtimePostgresChangesPayload } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'
import { user } from './useAuth'
import { ensureDriverProfile, patchLocal, type RelocationRequest } from './useRequests'
import { pushToast } from './useToasts'

/**
 * The order below is the whole slice. Getting it wrong produces a channel that reports
 * SUBSCRIBED and delivers nothing — a healthy-looking socket with zero events:
 *
 *   1. getSession()
 *   2. supabase.realtime.setAuth(access_token)      ← BEFORE any channel exists
 *   3. setAuth again on every TOKEN_REFRESHED
 *   4. only then create the channel, in onMounted
 *   5. removeChannel in onUnmounted
 *
 * supabase-js does not hand the session token to the Realtime socket by itself. And a
 * channel created at module top level runs before the session is restored from storage,
 * which is the same failure with a harder-to-see cause.
 */
export function useRequestsRealtime(): void {
  let channel: RealtimeChannel | null = null
  let stopAuthListener: (() => void) | null = null

  function handle(payload: RealtimePostgresChangesPayload<RelocationRequest>): void {
    const uid = user.value?.id
    if (!uid) return

    const next = payload.new as RelocationRequest | undefined
    const prev = payload.old as Partial<RelocationRequest> | undefined
    if (!next?.id) return

    // Reads are open to authenticated, so this channel sees every dispatcher's rows.
    // Filtering here rather than in the policy is deliberate: a narrower SELECT policy
    // would make Realtime drop the post-booking UPDATE for anyone but the booker.
    if (next.dispatcher_id !== uid) return

    // Patch in place. Refetching the whole list on every event would work and would also
    // throw away the reason for using a change stream.
    patchLocal(next)

    // The money shot: this UPDATE is the one where a driver takes the gig.
    const justBooked = !prev?.driver_id && next.driver_id
    if (justBooked && next.driver_id) {
      void ensureDriverProfile(next.driver_id).then((driver) => {
        const who = driver?.full_name ?? 'A driver'
        pushToast('success', `${who} booked ${next.origin} → ${next.destination}.`)
      })
    }
  }

  onMounted(async () => {
    const { data, error } = await supabase.auth.getSession()
    if (error || !data.session) return

    supabase.realtime.setAuth(data.session.access_token)

    const { data: sub } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'TOKEN_REFRESHED' && session) {
        supabase.realtime.setAuth(session.access_token)
      }
    })
    stopAuthListener = () => sub.subscription.unsubscribe()

    // One channel per concern. supabase.channel('name') called twice creates a SECOND
    // channel — it does not return the existing one — and that is how one booking ends
    // up firing three toasts.
    channel = supabase
      .channel('dispatcher-requests')
      .on<RelocationRequest>(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'relocation_requests' },
        handle,
      )
      .subscribe((status) => {
        // SUBSCRIBED means the channel joined. It is not proof of delivery.
        if (status !== 'SUBSCRIBED') console.warn('[realtime] channel status:', status)
      })
  })

  onUnmounted(() => {
    stopAuthListener?.()
    if (channel) supabase.removeChannel(channel)
    channel = null
  })
}
