import { describe, expect, it } from 'vitest'
import {
  formatPaise,
  normalizeIndianPhone,
  paiseToRupees,
  phoneSchema,
  rupeesSchema,
  rupeesToPaise,
} from './validators'

describe('normalizeIndianPhone', () => {
  it('accepts a bare 10-digit number', () => {
    expect(normalizeIndianPhone('9876543210')).toBe('+919876543210')
  })

  it('accepts a number with spaces', () => {
    expect(normalizeIndianPhone('98765 43210')).toBe('+919876543210')
  })

  it('accepts a number with dashes', () => {
    expect(normalizeIndianPhone('9876-543-210')).toBe('+919876543210')
  })

  it('accepts a leading 0 (STD-style)', () => {
    expect(normalizeIndianPhone('09876543210')).toBe('+919876543210')
  })

  it('accepts a 91 prefix without +', () => {
    expect(normalizeIndianPhone('919876543210')).toBe('+919876543210')
  })

  it('accepts +91 already applied', () => {
    expect(normalizeIndianPhone('+919876543210')).toBe('+919876543210')
  })

  it('accepts +91 with spaces', () => {
    expect(normalizeIndianPhone('+91 98765 43210')).toBe('+919876543210')
  })

  it('rejects too few digits', () => {
    expect(normalizeIndianPhone('98765')).toBeNull()
  })

  it('rejects too many digits', () => {
    expect(normalizeIndianPhone('9876543210123')).toBeNull()
  })

  it('rejects non-numeric input', () => {
    expect(normalizeIndianPhone('not a phone')).toBeNull()
  })
})

describe('phoneSchema', () => {
  it('normalizes a valid phone on parse', () => {
    const result = phoneSchema.safeParse('98765 43210')
    expect(result.success).toBe(true)
    if (result.success) expect(result.data).toBe('+919876543210')
  })

  it('fails with a friendly message for invalid input', () => {
    const result = phoneSchema.safeParse('123')
    expect(result.success).toBe(false)
    if (!result.success) {
      expect(result.error.issues[0]?.message).toMatch(/valid.*phone/i)
    }
  })

  it('fails on empty input', () => {
    const result = phoneSchema.safeParse('')
    expect(result.success).toBe(false)
  })
})

describe('rupeesSchema', () => {
  it('accepts a positive whole number', () => {
    expect(rupeesSchema.safeParse(10000).success).toBe(true)
  })

  it('rejects decimals', () => {
    expect(rupeesSchema.safeParse(10000.5).success).toBe(false)
  })

  it('rejects zero', () => {
    expect(rupeesSchema.safeParse(0).success).toBe(false)
  })

  it('rejects negative numbers', () => {
    expect(rupeesSchema.safeParse(-500).success).toBe(false)
  })
})

describe('rupeesToPaise / paiseToRupees', () => {
  it('converts rupees to paise with exact integer math', () => {
    expect(rupeesToPaise(10000)).toBe(1000000)
  })

  it('converts paise back to rupees', () => {
    expect(paiseToRupees(1000000)).toBe(10000)
  })

  it('round-trips without floating point drift', () => {
    for (const rupees of [1, 999, 10000, 123456]) {
      expect(paiseToRupees(rupeesToPaise(rupees))).toBe(rupees)
    }
  })
})

describe('formatPaise', () => {
  it('always shows exactly two decimal places, even for a whole-rupee amount', () => {
    expect(formatPaise(1000000)).toBe('10,000.00')
  })

  it('never truncates a trailing zero (the bug this exists to prevent — ₹500.5 read as a wrong amount, not a rounding choice)', () => {
    expect(formatPaise(50050)).toBe('500.50')
  })

  it('formats a single non-zero decimal digit correctly', () => {
    expect(formatPaise(50001)).toBe('500.01')
  })

  it('applies Indian digit grouping for larger amounts', () => {
    expect(formatPaise(123456789)).toBe('12,34,567.89')
  })

  it('formats zero correctly', () => {
    expect(formatPaise(0)).toBe('0.00')
  })
})
