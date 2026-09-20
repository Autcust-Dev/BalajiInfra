import { defineConfig, devices } from '@playwright/test'

// Runs against a production build (npm run build && npm run preview), not the dev server —
// closer to what actually ships to Cloudflare Pages. All tests share one local Supabase
// database (no per-test data isolation), so this intentionally runs serially: `workers: 1`
// and no fullyParallel, to avoid two tests racing on the same seeded rows or the same
// admin's MFA enrollment.
export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL: 'http://localhost:4173',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  webServer: {
    command: 'npm run preview -- --port 4173',
    url: 'http://localhost:4173',
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
})
