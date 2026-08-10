import { ref } from 'vue'

export type ToastKind = 'success' | 'error'
export interface Toast {
  id: number
  kind: ToastKind
  message: string
}

export const toasts = ref<Toast[]>([])
let nextId = 1

export function pushToast(kind: ToastKind, message: string): void {
  const id = nextId++
  toasts.value = [...toasts.value, { id, kind, message }]
  window.setTimeout(() => dismissToast(id), kind === 'error' ? 7000 : 4000)
}

export function dismissToast(id: number): void {
  toasts.value = toasts.value.filter((t) => t.id !== id)
}
