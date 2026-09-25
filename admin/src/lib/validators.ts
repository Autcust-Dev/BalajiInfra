import { z } from 'zod'

/**
 * Accepts common Indian phone input shapes — 10 digits, with/without a leading 0 or 91/+91,
 * with spaces or dashes anywhere — and normalizes to the exact E.164 shape the database
 * constraint requires: `+91` followed by 10 digits. Returns null if the input can't be
 * confidently normalized.
 */
export function normalizeIndianPhone(raw: string): string | null {
  const digitsOnly = raw.replace(/\D/g, '')

  let national: string | null = null
  if (digitsOnly.length === 12 && digitsOnly.startsWith('91')) {
    national = digitsOnly.slice(2)
  } else if (digitsOnly.length === 11 && digitsOnly.startsWith('0')) {
    national = digitsOnly.slice(1)
  } else if (digitsOnly.length === 10) {
    national = digitsOnly
  }

  if (!national) return null
  return `+91${national}`
}

export const phoneSchema = z
  .string()
  .min(1, 'Phone number is required')
  .transform((val, ctx) => {
    const normalized = normalizeIndianPhone(val)
    if (!normalized) {
      ctx.addIssue({
        code: 'custom',
        message: 'Enter a valid 10-digit Indian phone number',
      })
      return z.NEVER
    }
    return normalized
  })

/** Whole rupees only — no decimals (rent is always a round number in practice, and this
 * keeps the paise conversion exact integer math). */
export const rupeesSchema = z
  .number({ error: 'Enter the monthly rent in rupees' })
  .int('Rent must be a whole number of rupees, no decimals')
  .positive('Rent must be greater than zero')

export function rupeesToPaise(rupees: number): number {
  return rupees * 100
}

export function paiseToRupees(paise: number): number {
  return paise / 100
}

/** The one place paise gets turned into a displayed rupee amount — always exactly two
 * decimal places (₹500.50, never ₹500.5), since this shows up on tenant-facing invoices
 * as well as admin screens and a truncated decimal reads as a wrong amount, not a
 * rounding choice. Callers still supply the ₹ prefix themselves (`₹{formatPaise(x)}`) —
 * this only owns the numeric formatting. */
export function formatPaise(paise: number): string {
  return paiseToRupees(paise).toLocaleString('en-IN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })
}
