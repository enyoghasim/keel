import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import path from 'node:path'
import { defineConfig } from 'vitest/config'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: { '@': path.resolve(import.meta.dirname, './src') },
  },
  server: {
    proxy: {
      // Proxy API and cable traffic to Rails so dev has one origin and no CORS.
      '/api': 'http://localhost:3000',
      // Direct uploads (the Assemble form) talk to Active Storage, outside /api.
      // xfwd keeps the browser's origin in the upload URL Rails hands back, so the PUT stays same-origin.
      '/rails/active_storage': { target: 'http://localhost:3000', xfwd: true },
      '/cable': {
        target: 'ws://localhost:3000',
        ws: true,
      },
    },
  },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: './src/test/setup.ts',
  },
})
