import { createRouter, createWebHistory } from 'vue-router'
import { initAuth, session } from '../composables/useAuth'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', name: 'signin', component: () => import('../views/SignInView.vue') },
    { path: '/requests', name: 'requests', component: () => import('../views/RequestsView.vue') },
    { path: '/:pathMatch(.*)*', redirect: { name: 'signin' } },
  ],
})

router.beforeEach(async (to) => {
  // Await the initial getSession() before deciding. Without this the guard runs against a
  // null session that has not been restored from localStorage yet, and a hard refresh
  // bounces an authenticated user to the sign-in page for one frame.
  await initAuth()

  const signedIn = session.value !== null
  if (signedIn && to.name === 'signin') return { name: 'requests' }
  if (!signedIn && to.name !== 'signin') return { name: 'signin' }
  return true
})

export default router
