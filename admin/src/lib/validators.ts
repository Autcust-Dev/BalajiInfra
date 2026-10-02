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

/** Same whole-rupee treatment as rent, but zero is valid — not every tenant has an advance
 * collected. */
export const advanceRupeesSchema = z
  .number({ error: 'Enter the advance amount in rupees' })
  .int('Advance must be a whole number of rupees, no decimals')
  .nonnegative('Advance cannot be negative')

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

/** A due's true total owed is its own amount plus the sum of its fines — never a stored/
 * computed column (see the comment on the fines table), so every screen that shows a due's
 * total calls this one function rather than re-deriving the same formula. */
export function dueTotalWithFines(due: {
  amount_paise: number
  fines: { amount_paise: number }[]
}): number {
  return due.amount_paise + due.fines.reduce((sum, f) => sum + f.amount_paise, 0)
}

/** When "Add rent due" generates a new due's date: the last day of the current month for a
 * monthly tenant, or the last day of the same month one year out for a yearly one — never
 * a monthly cadence for a yearly tenant, which is the actual bug this exists to prevent.
 * `setDate(0)` rolls back to the end of the *previous* month, which is why advancing the
 * month by one first (in both branches) is what actually lands on the end of the intended
 * month — easy to get backwards, hence a named, tested function instead of inlining it. */
export function nextRentDueDate(billingCycle: 'monthly' | 'yearly', from = new Date()): string {
  const dueDate = new Date(from)
  if (billingCycle === 'yearly') {
    dueDate.setFullYear(dueDate.getFullYear() + 1)
  }
  dueDate.setMonth(dueDate.getMonth() + 1, 0)
  return dueDate.toISOString().slice(0, 10)
}
