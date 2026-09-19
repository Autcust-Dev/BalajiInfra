import { expect, test } from '@playwright/test'
import { loginAs, OWNER } from './fixtures'

test('owner can log in end to end, including first-time MFA enrollment', async ({ page }) => {
  const consoleErrors: string[] = []
  page.on('console', (msg) => {
    if (msg.type() === 'error') consoleErrors.push(msg.text())
  })
  page.on('pageerror', (err) => consoleErrors.push(err.message))

  await loginAs(page, OWNER)

  await expect(page).toHaveURL(/\/properties$/)
  await expect(page.getByRole('heading', { name: 'Properties' })).toBeVisible()
  await expect(page.getByText('Fake Owner · owner')).toBeVisible()
  expect(consoleErrors).toEqual([])
})
