/** Single/double/triple sharing is derived from capacity, not stored — capacity is the
 * single source of truth (client confirmed: "sharing type is equal to its capacity"). */
export function sharingTypeLabel(capacity: number): string {
  switch (capacity) {
    case 1:
      return 'Single'
    case 2:
      return 'Double'
    case 3:
      return 'Triple'
    default:
      return `${capacity}-sharing`
  }
}
