import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { user } from './useAuth'

export type RequestStatus = 'open' | 'booked' | 'in_transit' | 'completed' | 'cancelled'

/** Hand-written to match supabase/migrations/0001_init.sql. The schema is the source of
 *  truth: propose a migration, never invent a column. */
export interface RelocationRequest {
  id: string
  dispatcher_id: string
  origin: string
  destination: string
  pickup_date: string
  notes: string | null
  vehicle_type: string | null
  price_cents: number
  status: RequestStatus
  driver_id: string | null
  booked_at: string | null
  created_at: string
  updated_at: string
}

export const REQUEST_COLUMNS =
  'id, dispatcher_id, origin, destination, pickup_date, notes, vehicle_type, ' +
  'price_cents, status, driver_id, booked_at, created_at, updated_at'

// Module-scoped, like useAuth: one list shared by every importer.
export const requests = ref<RelocationRequest[]>([])
export const loading = ref(false)
export const loadError = ref<string | null>(null)

/**
 * Reads are open to `authenticated` at the policy level (Realtime needs that — see the
 * migration's comment on requests_select_all), so the dispatcher filter lives here, in the UI.
 */
export async function fetchRequests(): Promise<void> {
  const uid = user.value?.id
  if (!uid) return

  loading.value = true
  loadError.value = null

  // .returns<T>() rather than a cast: without generated database types supabase-js cannot
  // infer a runtime-built column list and falls back to GenericStringError[], which a cast
  // would paper over.
  const { data, error } = await supabase
    .from('relocation_requests')
    .select(REQUEST_COLUMNS)
    .eq('dispatcher_id', uid)
    .order('created_at', { ascending: false })
    .returns<RelocationRequest[]>()

  loading.value = false

  // An error is surfaced, never collapsed into "no rows". Those two states look identical
  // in the response and mean opposite things.
  if (error) {
    loadError.value = error.message
    return
  }
  requests.value = data ?? []
}
