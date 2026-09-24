import { zodResolver } from '@hookform/resolvers/zod'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Plus } from 'lucide-react'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { Link } from 'react-router-dom'
import { toast } from 'sonner'
import { z } from 'zod'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
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
import { sharingTypeLabel } from '@/lib/rooms'
import { paiseToRupees, rupeesToPaise } from '@/lib/validators'
import { useAuth } from '@/lib/auth-context'
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

function useRoomsForProperty(propertyId: string | undefined) {
  return useQuery({
    queryKey: ['rooms-simple', propertyId],
    enabled: !!propertyId,
    queryFn: async () => {
      const { data, error } = await supabase
        .from('rooms')
        .select('id, room_number')
        .eq('property_id', propertyId!)
        .order('room_number')
      if (error) throw error
      return data
    },
  })
}

function useUnitsForRoom(roomId: string | undefined) {
  return useQuery({
    queryKey: ['room-units', roomId],
    enabled: !!roomId,
    queryFn: async () => {
      const { data, error } = await supabase
        .from('room_units')
        .select('id, capacity')
        .eq('room_id', roomId!)
        .order('capacity')
      if (error) throw error
      return data
    },
  })
}

function useBills() {
  return useQuery({
    queryKey: ['electricity-bills'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('electricity_bills')
        .select('*, room_units(capacity, rooms(room_number, properties(name)))')
        .order('billing_period', { ascending: false })
      if (error) throw error
      return data
    },
  })
}

const billSchema = z.object({
  property_id: z.string().min(1, 'Select a property'),
  room_id: z.string().min(1, 'Select a room'),
  room_unit_id: z.string().min(1, 'Select a sharing type'),
  billing_month: z.string().min(1, 'Select a billing month'), // <input type="month"> value, "YYYY-MM"
  total_amount_rupees: z
    .number({ error: 'Enter the total bill amount' })
    .positive('Must be greater than zero'),
})
type BillValues = z.infer<typeof billSchema>

function AddBillDialog() {
  const [open, setOpen] = useState(false)
  const queryClient = useQueryClient()
  const { adminProfile } = useAuth()
  const { data: properties } = usePropertiesQuery()
  const form = useForm<BillValues>({
    resolver: zodResolver(billSchema),
    defaultValues: {
      property_id: '',
      room_id: '',
      room_unit_id: '',
      billing_month: '',
      total_amount_rupees: 0,
    },
  })
  const propertyId = form.watch('property_id')
  const { data: rooms } = useRoomsForProperty(propertyId || undefined)
  const roomId = form.watch('room_id')
  const { data: units } = useUnitsForRoom(roomId || undefined)

  async function onSubmit(values: BillValues) {
    if (!adminProfile) return
    const billing_period = `${values.billing_month}-01`
    const { error } = await supabase.from('electricity_bills').insert({
      room_unit_id: values.room_unit_id,
      billing_period,
      total_amount_paise: rupeesToPaise(values.total_amount_rupees),
      created_by: adminProfile.id,
    })
    if (error) {
      toast.error(
        error.code === '23505'
          ? 'A bill for this room and month already exists — edit its total instead.'
          : error.message,
      )
      return
    }
    toast.success('Bill added and split among the room’s active tenants')
    await queryClient.invalidateQueries({ queryKey: ['electricity-bills'] })
    setOpen(false)
    form.reset()
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm">
          <Plus className="size-4" />
          Add bill
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Add electricity bill</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="property_id"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Property</FormLabel>
                  <Select
                    value={field.value}
                    onValueChange={(v) => {
                      field.onChange(v)
                      form.setValue('room_id', '')
                      form.setValue('room_unit_id', '')
                    }}
                  >
                    <FormControl>
                      <SelectTrigger className="w-full">
                        <SelectValue placeholder="Select a property" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {properties?.map((p) => (
                        <SelectItem key={p.id} value={p.id}>
                          {p.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="room_id"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Room</FormLabel>
                  <Select
                    value={field.value}
                    onValueChange={(v) => {
                      field.onChange(v)
                      form.setValue('room_unit_id', '')
                    }}
                    disabled={!propertyId}
                  >
                    <FormControl>
                      <SelectTrigger className="w-full">
                        <SelectValue placeholder="Select a room" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {rooms?.map((r) => (
                        <SelectItem key={r.id} value={r.id}>
                          {r.room_number}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="room_unit_id"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Sharing type</FormLabel>
                  <Select value={field.value} onValueChange={field.onChange} disabled={!roomId}>
                    <FormControl>
                      <SelectTrigger className="w-full">
                        <SelectValue placeholder="Select a sharing type" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {units?.map((u) => (
                        <SelectItem key={u.id} value={u.id}>
                          {sharingTypeLabel(u.capacity)}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  {roomId && units?.length === 0 && (
                    <p className="text-muted-foreground text-sm">
                      This room has no sharing units yet — add one from the Rooms page first.
                    </p>
                  )}
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="billing_month"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Billing month</FormLabel>
                  <FormControl>
                    <Input type="month" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="total_amount_rupees"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Total amount (₹)</FormLabel>
                  <FormControl>
                    <Input
                      type="number"
                      min={1}
                      step={1}
                      {...field}
                      onChange={(e) => field.onChange(Number(e.target.value))}
                    />
                  </FormControl>
                  <p className="text-muted-foreground text-xs">
                    Split evenly among this sharing unit&rsquo;s active tenants automatically — a
                    single-sharing unit is never split, and you can edit any tenant&rsquo;s share
                    afterward.
                  </p>
                  <FormMessage />
                </FormItem>
              )}
            />
            <Button type="submit" className="w-full" disabled={form.formState.isSubmitting}>
              Save
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  )
}

export function EBillsPage() {
  const { data: bills, isLoading } = useBills()

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-foreground text-xl font-medium">E-Bills</h1>
        <AddBillDialog />
      </div>

      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Property</TableHead>
            <TableHead>Room</TableHead>
            <TableHead>Sharing</TableHead>
            <TableHead>Month</TableHead>
            <TableHead>Total</TableHead>
            <TableHead className="w-24" />
          </TableRow>
        </TableHeader>
        <TableBody>
          {isLoading && (
            <TableRow>
              <TableCell colSpan={6}>Loading…</TableCell>
            </TableRow>
          )}
          {bills?.length === 0 && (
            <TableRow>
              <TableCell colSpan={6} className="text-muted-foreground">
                No bills yet.
              </TableCell>
            </TableRow>
          )}
          {bills?.map((bill) => (
            <TableRow key={bill.id}>
              <TableCell>{bill.room_units?.rooms?.properties?.name}</TableCell>
              <TableCell>{bill.room_units?.rooms?.room_number}</TableCell>
              <TableCell>
                {bill.room_units ? sharingTypeLabel(bill.room_units.capacity) : ''}
              </TableCell>
              <TableCell>
                {new Date(bill.billing_period).toLocaleDateString('en-IN', {
                  month: 'long',
                  year: 'numeric',
                })}
              </TableCell>
              <TableCell>
                ₹{paiseToRupees(bill.total_amount_paise).toLocaleString('en-IN')}
              </TableCell>
              <TableCell className="text-right">
                <Button asChild variant="outline" size="sm">
                  <Link to={`/ebills/${bill.id}`}>Details</Link>
                </Button>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  )
}
