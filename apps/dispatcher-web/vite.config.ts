import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

// Tailwind v4 is a Vite plugin. There is no postcss.config.js and no tailwind.config.js
// in v4 — generating the v3 PostCSS setup against a v4 install fails silently or with
// "trying to use tailwindcss directly as a PostCSS plugin". See CLAUDE.md.
export default defineConfig({
  plugins: [vue(), tailwindcss()],
  server: { port: 5173, strictPort: true }, // 5173 is the only allow-listed local origin
})
