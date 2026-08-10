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

/** What the form is allowed to send. Note what is absent: dispatcher_id and status.
 *  Both have column defaults — `default auth.uid()` and `default 'open'` — and sending
 *  them from the client would mean trusting the client with authorship and state. */
export interface RequestDraft {
  origin: string
  destination: string
  pickup_date: string
  notes: string | null
  vehicle_type: string | null
  price_cents: number
}

export async function createRequest(draft: RequestDraft): Promise<RelocationRequest> {
  const { data, error } = await supabase
    .from('relocation_requests')
    .insert(draft)
    .select(REQUEST_COLUMNS)
    .single<RelocationRequest>()

  // PostgREST answers a policy rejection with 200 and no row, so "no error" is not "success".
  if (error) throw new Error(error.message)
  if (!data) throw new Error('The write was rejected — no row came back.')

  requests.value = [data, ...requests.value]
  return data
}

export async function updateRequest(
  id: string,
  patch: Partial<RequestDraft>,
): Promise<RelocationRequest> {
  const { data, error } = await supabase
    .from('relocation_requests')
    .update(patch)
    .eq('id', id)
    .select(REQUEST_COLUMNS)
    .single<RelocationRequest>()

  if (error) throw new Error(error.message)
  if (!data) throw new Error('The write was rejected — no row came back.')

  patchLocal(data)
  return data
}

/** Cancelling is a status transition, never a SQL DELETE: a cancelled gig keeps its history,
 *  and the booked_requires_driver CHECK is written to allow 'cancelled' from any state. */
export async function cancelRequest(id: string): Promise<RelocationRequest> {
  const { data, error } = await supabase
    .from('relocation_requests')
    .update({ status: 'cancelled' })
    .eq('id', id)
    .select(REQUEST_COLUMNS)
    .single<RelocationRequest>()

  if (error) throw new Error(error.message)
  if (!data) throw new Error('The write was rejected — no row came back.')

  patchLocal(data)
  return data
}

/** The money shot needs the booking driver's face and name. profiles_select_all is
 *  `using (true)` precisely so the dispatcher can read them. Cached per id: a booking
 *  storm must not turn into one request per event. */
export interface DriverProfile {
  id: string
  full_name: string | null
  avatar_url: string | null
}
export const driverProfiles = ref<Record<string, DriverProfile>>({})

export async function ensureDriverProfile(id: string): Promise<DriverProfile | null> {
  const cached = driverProfiles.value[id]
  if (cached) return cached

  const { data, error } = await supabase
    .from('profiles')
    .select('id, full_name, avatar_url')
    .eq('id', id)
    .maybeSingle<DriverProfile>()

  if (error || !data) return null
  driverProfiles.value = { ...driverProfiles.value, [id]: data }
  return data
}

export function patchLocal(row: RelocationRequest): void {
  const i = requests.value.findIndex((r) => r.id === row.id)
  if (i === -1) requests.value = [row, ...requests.value]
  else requests.value[i] = row
}
