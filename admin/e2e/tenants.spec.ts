import { expect, test } from '@playwright/test'
import { loginAs, OWNER } from './fixtures'

test('owner can add a tenant, then move them out', async ({ page }) => {
  await loginAs(page, OWNER)

  await page.getByRole('link', { name: 'Tenants' }).click()
  await expect(page.getByText('Fake Tenant Approved')).toBeVisible()

  // --- Add tenant ---
  await page.getByRole('link', { name: 'Add tenant' }).click()
  await expect(page).toHaveURL(/\/tenants\/new$/)

  await page.getByLabel('Full name').fill('E2E Test Tenant')
  await page.getByLabel('Phone').fill('98765 22222') // normalized to +919876522222
  await page.getByRole('combobox').first().click() // property
  await page.getByRole('option', { name: 'Fake PG Bangalore' }).click()
  await page.getByRole('combobox').nth(1).click() // room, populated once property is chosen
  await page.getByRole('option').first().click()
  await page.getByLabel('Monthly rent').fill('15000')
  await page.getByRole('button', { name: 'Save' }).click()

  await expect(page).toHaveURL(/\/tenants$/)
  await expect(page.getByText('E2E Test Tenant')).toBeVisible()

  // --- Move out ---
  await page
    .locator('tr', { hasText: 'E2E Test Tenant' })
    .getByRole('link', { name: 'Edit' })
    .click()
  await expect(page).toHaveURL(/\/tenants\/.+\/edit$/)

  await page.getByRole('button', { name: 'Move out' }).click()
  await expect(page.getByText('Move out E2E Test Tenant?')).toBeVisible()
  await page.getByRole('button', { name: 'Confirm move-out' }).click()

  await expect(page).toHaveURL(/\/tenants$/)
  await expect(page.locator('tr', { hasText: 'E2E Test Tenant' })).toContainText('moved_out')
})
