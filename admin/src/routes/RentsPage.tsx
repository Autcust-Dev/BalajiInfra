import { zodResolver } from '@hookform/resolvers/zod'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { toast } from 'sonner'
import { z } from 'zod'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form'
import { Input } from '@/components/ui/input'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { useAuth } from '@/lib/auth-context'
import { sharingTypeLabel } from '@/lib/rooms'
import { formatPaise, rupeesToPaise } from '@/lib/validators'
import { supabase } from '@/lib/supabase'

function usePropertiesQuery() {
  return useQuery({
    queryKey: ['properties'],
    queryFn: async () => {
      const { data, error } = await supabase.from('properties').select('*').order('name')
      if (error) throw error
      return data
    },
  })
}

function useRentsData(propertyId: string | undefined) {
  return useQuery({
    queryKey: ['rents', propertyId],
    enabled: !!propertyId,
    queryFn: async () => {
      const { data: tenants, error: tenantsError } = await supabase
        .from('tenants')
        .select(
          'id, full_name, monthly_rent_paise, billing_cycle, room_units(capacity, rooms(room_number))',
        )
        .eq('property_id', propertyId!)
        .eq('status', 'active')
        .order('full_name')
      if (tenantsError) throw tenantsError

      const tenantIds = tenants.map((t) => t.id)

      const { data: dues, error: duesError } = await supabase
        .from('dues')
        .select('id, tenant_id, type, amount_paise, status, due_date, fines(amount_paise)')
        .in('tenant_id', tenantIds)
        .eq('type', 'rent')
        .order('due_date', { ascending: false })
      if (duesError) throw duesError

      const duesByTenant = new Map<string, typeof dues>()
      for (const due of dues) {
        const list = duesByTenant.get(due.tenant_id) ?? []
        list.push(due)
        duesByTenant.set(due.tenant_id, list)
      }

      return { tenants, duesByTenant }
    },
  })
}

function dueTotal(due: { amount_paise: number; fines: { amount_paise: number }[] }) {
  return due.amount_paise + due.fines.reduce((sum, f) => sum + f.amount_paise, 0)
}

function AddRentDueButton({
  tenantId,
  amountPaise,
  propertyId,
  hasUnpaidDue,
}: {
  tenantId: string
  amountPaise: number
  propertyId: string
  hasUnpaidDue: boolean
}) {
  const queryClient = useQueryClient()
  const { adminProfile } = useAuth()
  const [loading, setLoading] = useState(false)

  async function addDue() {
    if (!adminProfile) return
    setLoading(true)
    const dueDate = new Date()
    dueDate.setMonth(dueDate.getMonth() + 1, 0) // last day of current month
    const { error } = await supabase.from('dues').insert({
      tenant_id: tenantId,
      type: 'rent',
      description: 'Rent',
      amount_paise: amountPaise,
      due_date: dueDate.toISOString().slice(0, 10),
      status: 'unpaid',
      created_by: adminProfile.id,
    })
    setLoading(false)
    if (error) {
      toast.error(error.message)
      return
    }
    toast.success('Rent due added')
    await queryClient.invalidateQueries({ queryKey: ['rents', propertyId] })
  }

  return (
    <Button
      size="sm"
      variant="outline"
      onClick={() => void addDue()}
      disabled={loading || hasUnpaidDue}
      title={hasUnpaidDue ? 'This tenant already has an unpaid rent due' : undefined}
    >
      Add rent due
    </Button>
  )
}

const fineSchema = z.object({
  amount_rupees: z.number({ error: 'Enter a fine amount' }).positive('Must be greater than zero'),
  starts_on: z.string().min(1, 'Select a start date'),
  ends_on: z.string().min(1, 'Select an end date'),
})
type FineValues = z.infer<typeof fineSchema>

function AddFineDialog({ dueId, propertyId }: { dueId: string; propertyId: string }) {
  const [open, setOpen] = useState(false)
  const [enabled, setEnabled] = useState(false)
  const queryClient = useQueryClient()
  const { adminProfile } = useAuth()
  const form = useForm<FineValues>({
    resolver: zodResolver(fineSchema),
    defaultValues: { amount_rupees: 0, starts_on: '', ends_on: '' },
  })

  async function onSubmit(values: FineValues) {
    if (!adminProfile) return
    if (values.ends_on < values.starts_on) {
      form.setError('ends_on', { message: 'End date must be on or after the start date' })
      return
    }
    const { error } = await supabase.from('fines').insert({
      due_id: dueId,
      amount_paise: rupeesToPaise(values.amount_rupees),
      starts_on: values.starts_on,
      ends_on: values.ends_on,
      created_by: adminProfile.id,
    })
    if (error) {
      toast.error(error.message)
      return
    }
    toast.success('Fine added')
    await queryClient.invalidateQueries({ queryKey: ['rents', propertyId] })
    setOpen(false)
    setEnabled(false)
    form.reset()
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        setOpen(next)
        if (!next) {
          setEnabled(false)
          form.reset()
        }
      }}
    >
      <DialogTrigger asChild>
        <Button size="sm" variant="ghost">
          Add fine
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Add fine</DialogTitle>
        </DialogHeader>
        <div className="flex items-center gap-2">
          <Checkbox checked={enabled} onCheckedChange={(v) => setEnabled(v === true)} />
          <span className="text-sm">Apply a fine to this due</span>
        </div>
        {enabled && (
          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
              <FormField
                control={form.control}
                name="amount_rupees"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Fine amount (₹)</FormLabel>
                    <FormControl>
                      <Input
                        type="number"
                        min={1}
                        {...field}
                        onChange={(e) => field.onChange(Number(e.target.value))}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={form.control}
                name="starts_on"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Starts on</FormLabel>
                    <FormControl>
                      <Input type="date" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={form.control}
                name="ends_on"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Ends on</FormLabel>
                    <FormControl>
                      <Input type="date" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <DialogFooter>
                <Button type="submit" disabled={form.formState.isSubmitting}>
                  Save
                </Button>
              </DialogFooter>
            </form>
          </Form>
        )}
      </DialogContent>
    </Dialog>
  )
}

export function RentsPage() {
  const { data: properties } = usePropertiesQuery()
  const [propertyId, setPropertyId] = useState<string>('')
  const activePropertyId = propertyId || properties?.[0]?.id
  const { data, isLoading } = useRentsData(activePropertyId)

  const tenants = data?.tenants ?? []
  const duesByTenant: NonNullable<typeof data>['duesByTenant'] = data?.duesByTenant ?? new Map()

  let totalExpected = 0
  let totalPending = 0
  for (const tenant of tenants) {
    totalExpected += tenant.monthly_rent_paise
    const dues = duesByTenant.get(tenant.id) ?? []
    for (const due of dues) {
      if (due.status !== 'paid') totalPending += dueTotal(due)
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-foreground text-xl font-medium">Rents</h1>
        <Select value={activePropertyId} onValueChange={setPropertyId}>
          <SelectTrigger className="w-56">
            <SelectValue placeholder="Select a property" />
          </SelectTrigger>
          <SelectContent>
            {properties?.map((p) => (
              <SelectItem key={p.id} value={p.id}>
                {p.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {activePropertyId && (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
          <div className="rounded-md border p-4">
            <p className="text-muted-foreground text-xs">Active tenants</p>
            <p className="text-lg font-medium">{tenants.length}</p>
          </div>
          <div className="rounded-md border p-4">
            <p className="text-muted-foreground text-xs">Monthly rent expected</p>
            <p className="text-lg font-medium">₹{formatPaise(totalExpected)}</p>
          </div>
          <div className="rounded-md border p-4">
            <p className="text-muted-foreground text-xs">Pending (unpaid dues + fines)</p>
            <p className="text-lg font-medium">₹{formatPaise(totalPending)}</p>
          </div>
        </div>
      )}

      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Tenant</TableHead>
            <TableHead>Room</TableHead>
            <TableHead>Cycle</TableHead>
            <TableHead>Monthly rent</TableHead>
            <TableHead>Latest due</TableHead>
            <TableHead className="w-56" />
          </TableRow>
        </TableHeader>
        <TableBody>
          {isLoading && (
            <TableRow>
              <TableCell colSpan={6}>Loading…</TableCell>
            </TableRow>
          )}
          {!isLoading && tenants.length === 0 && (
            <TableRow>
              <TableCell colSpan={6} className="text-muted-foreground">
                No active tenants for this property.
              </TableCell>
            </TableRow>
          )}
          {tenants.map((tenant) => {
            const dues = duesByTenant.get(tenant.id) ?? []
            const latestDue = dues[0]
            const hasUnpaidDue = dues.some((d) => d.status === 'unpaid')
            return (
              <TableRow key={tenant.id}>
                <TableCell>{tenant.full_name}</TableCell>
                <TableCell className="text-muted-foreground">
                  {tenant.room_units?.rooms?.room_number}
                  {tenant.room_units ? ` · ${sharingTypeLabel(tenant.room_units.capacity)}` : ''}
                </TableCell>
                <TableCell className="capitalize">{tenant.billing_cycle}</TableCell>
                <TableCell>₹{formatPaise(tenant.monthly_rent_paise)}</TableCell>
                <TableCell>
                  {latestDue ? (
                    <Badge variant={latestDue.status === 'paid' ? 'secondary' : 'outline'}>
                      ₹{formatPaise(dueTotal(latestDue))} · {latestDue.status}
                    </Badge>
                  ) : (
                    <span className="text-muted-foreground text-sm">No dues yet</span>
                  )}
                </TableCell>
                <TableCell className="flex justify-end gap-2">
                  <AddRentDueButton
                    tenantId={tenant.id}
                    amountPaise={tenant.monthly_rent_paise}
                    propertyId={activePropertyId!}
                    hasUnpaidDue={hasUnpaidDue}
                  />
                  {latestDue && latestDue.status !== 'paid' && (
                    <AddFineDialog dueId={latestDue.id} propertyId={activePropertyId!} />
                  )}
                </TableCell>
              </TableRow>
            )
          })}
        </TableBody>
      </Table>
    </div>
  )
}
