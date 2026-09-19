import path from 'node:path'
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { configDefaults, defineConfig } from 'vitest/config'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': path.resolve(import.meta.dirname, './src'),
    },
  },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
    // e2e/**/*.spec.ts are Playwright specs (run via `npm run test:e2e`), not Vitest —
    // they'd otherwise match Vitest's default *.spec.ts pattern and fail to run under the
    // wrong test runner. Extend, don't replace, Vitest's own default excludes.
    exclude: [...configDefaults.exclude, 'e2e/**'],
  },
})
