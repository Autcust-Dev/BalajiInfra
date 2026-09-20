import { expect, test } from '@playwright/test'
import { loginAs, OWNER, STAFF } from './fixtures'

test('owner sees full property management controls', async ({ page }) => {
  await loginAs(page, OWNER)
  await expect(page.getByRole('button', { name: 'Add property' })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Edit' }).first()).toBeVisible()
})

test('staff sees properties read-only, matching Phase 1 RLS', async ({ page }) => {
  await loginAs(page, STAFF)
  await expect(page.getByRole('heading', { name: 'Properties' })).toBeVisible()
  await expect(page.getByText('Fake PG Bangalore')).toBeVisible()
  await expect(page.getByRole('button', { name: 'Add property' })).toHaveCount(0)
  await expect(page.getByRole('button', { name: 'Edit' })).toHaveCount(0)
})
