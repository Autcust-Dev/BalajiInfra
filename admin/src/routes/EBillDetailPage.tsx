import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { toast } from 'sonner'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { sharingTypeLabel } from '@/lib/rooms'
import { formatPaise, paiseToRupees, rupeesToPaise } from '@/lib/validators'
import { supabase } from '@/lib/supabase'

function useBillDetail(billId: string) {
  return useQuery({
    queryKey: ['electricity-bill-detail', billId],
    queryFn: async () => {
      const { data: bill, error: billError } = await supabase
        .from('electricity_bills')
        .select('*, room_units(capacity, rooms(room_number, properties(name)))')
        .eq('id', billId)
        .single()
      if (billError) throw billError

      const { data: splits, error: splitsError } = await supabase
        .from('electricity_bill_splits')
        .select('id, tenant_id, tenants(full_name, status), dues(id, amount_paise, status)')
        .eq('bill_id', billId)
      if (splitsError) throw splitsError

      return { bill, splits }
    },
  })
}

function EditableAmount({
  dueId,
  amountPaise,
  locked,
  billId,
}: {
  dueId: string
  amountPaise: number
  locked: boolean
  billId: string
}) {
  const [editing, setEditing] = useState(false)
  const [value, setValue] = useState(String(paiseToRupees(amountPaise)))
  const queryClient = useQueryClient()

  async function save() {
    const rupees = Number(value)
    if (!Number.isFinite(rupees) || rupees <= 0) {
      toast.error('Enter a valid amount')
      return
    }
    const { error } = await supabase
      .from('dues')
      .update({ amount_paise: rupeesToPaise(rupees) })
      .eq('id', dueId)
    if (error) {
      toast.error(error.message)
      return
    }
    toast.success('Updated')
    setEditing(false)
    await queryClient.invalidateQueries({ queryKey: ['electricity-bill-detail', billId] })
  }

  if (locked) {
    return <span>₹{formatPaise(amountPaise)}</span>
  }

  if (!editing) {
    return (
      <button
        type="button"
        className="hover:underline"
        onClick={() => {
          setValue(String(paiseToRupees(amountPaise)))
          setEditing(true)
        }}
      >
        ₹{formatPaise(amountPaise)}
      </button>
    )
  }

  return (
    <div className="flex items-center gap-1">
      <Input
        type="number"
        className="h-8 w-24"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        autoFocus
      />
      <Button size="sm" onClick={() => void save()}>
        Save
      </Button>
      <Button size="sm" variant="ghost" onClick={() => setEditing(false)}>
        Cancel
      </Button>
    </div>
  )
}

export function EBillDetailPage() {
  const { billId } = useParams<{ billId: string }>()
  const { data, isLoading } = useBillDetail(billId!)

  if (isLoading || !data) {
    return <p className="text-muted-foreground text-sm">Loading…</p>
  }

  const { bill, splits } = data
  const total = splits.reduce((sum, s) => sum + (s.dues?.amount_paise ?? 0), 0)

  return (
    <div className="max-w-2xl space-y-4">
      <Link to="/ebills" className="text-muted-foreground text-sm hover:underline">
        ← E-Bills
      </Link>
      <div>
        <h1 className="text-foreground text-xl font-medium">
          {bill.room_units?.rooms?.properties?.name} · Room {bill.room_units?.rooms?.room_number} ·{' '}
          {bill.room_units ? sharingTypeLabel(bill.room_units.capacity) : ''}
        </h1>
        <p className="text-muted-foreground text-sm">
          {new Date(bill.billing_period).toLocaleDateString('en-IN', {
            month: 'long',
            year: 'numeric',
          })}{' '}
          · Total ₹{formatPaise(bill.total_amount_paise)}
        </p>
      </div>

      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Tenant</TableHead>
            <TableHead>Share</TableHead>
            <TableHead>Status</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {splits.map((split) => {
            const locked = split.dues?.status === 'paid' || split.tenants?.status === 'moved_out'
            return (
              <TableRow key={split.id}>
                <TableCell>
                  {split.tenants?.full_name}
                  {split.tenants?.status === 'moved_out' && (
                    <Badge variant="outline" className="ml-2">
                      Moved out
                    </Badge>
                  )}
                </TableCell>
                <TableCell>
                  {split.dues && (
                    <EditableAmount
                      dueId={split.dues.id}
                      amountPaise={split.dues.amount_paise}
                      locked={locked}
                      billId={billId!}
                    />
                  )}
                </TableCell>
                <TableCell>
                  <Badge variant={split.dues?.status === 'paid' ? 'secondary' : 'outline'}>
                    {split.dues?.status}
                  </Badge>
                </TableCell>
              </TableRow>
            )
          })}
        </TableBody>
      </Table>

      <p className="text-muted-foreground text-sm">
        Sum of shares: ₹{formatPaise(total)} (bill total ₹{formatPaise(bill.total_amount_paise)})
      </p>
    </div>
  )
}
