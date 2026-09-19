import { zodResolver } from '@hookform/resolvers/zod'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useState } from 'react'
import { useForm } from 'react-hook-form'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { toast } from 'sonner'
import { z } from 'zod'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from '@/components/ui/alert-dialog'
import { Button } from '@/components/ui/button'
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
import { phoneSchema, rupeesSchema, paiseToRupees, rupeesToPaise } from '@/lib/validators'
import { supabase } from '@/lib/supabase'

const tenantFormSchema = z.object({
  full_name: z.string().min(1, 'Full name is required'),
  phone: phoneSchema,
  property_id: z.string().min(1, 'Select a property'),
  room_id: z.string().min(1, 'Select a room'),
  move_in_date: z.string().min(1, 'Move-in date is required'),
  monthly_rent_rupees: rupeesSchema,
})
type TenantFormValues = z.infer<typeof tenantFormSchema>

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
    queryKey: ['rooms', propertyId],
    enabled: !!propertyId,
    queryFn: async () => {
      const [roomsRes, tenantsRes] = await Promise.all([
        supabase.from('rooms').select('*').eq('property_id', propertyId!).order('room_number'),
        supabase
          .from('tenants')
          .select('room_id')
          .eq('property_id', propertyId!)
          .eq('status', 'active'),
      ])
      if (roomsRes.error) throw roomsRes.error
      if (tenantsRes.error) throw tenantsRes.error
      const occupancyByRoom = new Map<string, number>()
      for (const t of tenantsRes.data) {
        occupancyByRoom.set(t.room_id, (occupancyByRoom.get(t.room_id) ?? 0) + 1)
      }
      return roomsRes.data.map((room) => ({
        ...room,
        occupancy: occupancyByRoom.get(room.id) ?? 0,
      }))
    },
  })
}

function MoveOutDialog({ tenantId, tenantName }: { tenantId: string; tenantName: string }) {
  const navigate = useNavigate()
  const [moveOutDate, setMoveOutDate] = useState(new Date().toISOString().slice(0, 10))
  const [submitting, setSubmitting] = useState(false)

  async function confirmMoveOut() {
    setSubmitting(true)
    const { error } = await supabase
      .from('tenants')
      .update({ status: 'moved_out', move_out_date: moveOutDate })
      .eq('id', tenantId)
    setSubmitting(false)
    if (error) {
      toast.error(error.message)
      return
    }
    toast.success(`${tenantName} has been moved out`)
    navigate('/tenants')
  }

  return (
    <AlertDialog>
      <AlertDialogTrigger asChild>
        <Button variant="destructive">Move out</Button>
      </AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Move out {tenantName}?</AlertDialogTitle>
          <AlertDialogDescription>
            This immediately revokes all of their app access — they won't even be able to see their
            own tenant record anymore. This can't be undone from the app.
          </AlertDialogDescription>
        </AlertDialogHeader>
        <div className="space-y-2 py-2">
          <label className="text-sm font-medium" htmlFor="move-out-date">
            Move-out date
          </label>
          <Input
            id="move-out-date"
            type="date"
            value={moveOutDate}
            onChange={(e) => setMoveOutDate(e.target.value)}
          />
        </div>
        <AlertDialogFooter>
          <AlertDialogCancel>Cancel</AlertDialogCancel>
          <AlertDialogAction
            disabled={!moveOutDate || submitting}
            onClick={() => void confirmMoveOut()}
          >
            Confirm move-out
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  )
}

export function TenantFormPage() {
  const { tenantId } = useParams<{ tenantId: string }>()
  const navigate = useNavigate()
  const isEditing = !!tenantId

  const { data: tenant } = useQuery({
    queryKey: ['tenant', tenantId],
    enabled: isEditing,
    queryFn: async () => {
      const { data, error } = await supabase
        .from('tenants')
        .select('*')
        .eq('id', tenantId!)
        .single()
      if (error) throw error
      return data
    },
  })

  const { data: properties } = usePropertiesQuery()
  const queryClient = useQueryClient()

  const form = useForm<TenantFormValues>({
    resolver: zodResolver(tenantFormSchema),
    defaultValues: {
      full_name: '',
      phone: '',
      property_id: '',
      room_id: '',
      move_in_date: new Date().toISOString().slice(0, 10),
      monthly_rent_rupees: 0,
    },
  })

  useEffect(() => {
    if (tenant) {
      form.reset({
        full_name: tenant.full_name,
        phone: tenant.phone,
        property_id: tenant.property_id,
        room_id: tenant.room_id,
        move_in_date: tenant.move_in_date,
        monthly_rent_rupees: paiseToRupees(tenant.monthly_rent_paise),
      })
    }
  }, [tenant, form])

  const propertyId = form.watch('property_id')
  const { data: rooms } = useRoomsForProperty(propertyId || undefined)
  const selectedRoom = rooms?.find((r) => r.id === form.watch('room_id'))
  const roomIsFull = selectedRoom ? selectedRoom.occupancy >= selectedRoom.capacity : false

  async function onSubmit(values: TenantFormValues) {
    const payload = {
      full_name: values.full_name,
      phone: values.phone,
      property_id: values.property_id,
      room_id: values.room_id,
      move_in_date: values.move_in_date,
      monthly_rent_paise: rupeesToPaise(values.monthly_rent_rupees),
    }

    const { error } = isEditing
      ? await supabase.from('tenants').update(payload).eq('id', tenantId!)
      : await supabase
          .from('tenants')
          .insert({ ...payload, status: 'active', kyc_status: 'not_started' })

    if (error) {
      toast.error(
        error.code === '23505' ? 'A tenant with this phone number already exists.' : error.message,
      )
      return
    }
    toast.success(isEditing ? 'Tenant updated' : 'Tenant added')
    await queryClient.invalidateQueries({ queryKey: ['tenants'] })
    navigate('/tenants')
  }

  return (
    <div className="max-w-md space-y-4">
      <Link to="/tenants" className="text-muted-foreground text-sm hover:underline">
        ← Tenants
      </Link>
      <div className="flex items-center justify-between">
        <h1 className="text-foreground text-xl font-medium">
          {isEditing ? 'Edit tenant' : 'Add tenant'}
        </h1>
        {isEditing && tenant?.status === 'active' && (
          <MoveOutDialog tenantId={tenant.id} tenantName={tenant.full_name} />
        )}
      </div>

      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
          <FormField
            control={form.control}
            name="full_name"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Full name</FormLabel>
                <FormControl>
                  <Input {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
          <FormField
            control={form.control}
            name="phone"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Phone</FormLabel>
                <FormControl>
                  <Input placeholder="98765 43210" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
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
                <Select value={field.value} onValueChange={field.onChange} disabled={!propertyId}>
                  <FormControl>
                    <SelectTrigger className="w-full">
                      <SelectValue placeholder="Select a room" />
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    {rooms?.map((r) => (
                      <SelectItem key={r.id} value={r.id}>
                        {r.room_number} ({r.occupancy}/{r.capacity})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                {roomIsFull && (
                  <p className="text-destructive text-sm">
                    This room is already at capacity — you can still assign the tenant, but double
                    check that's intended.
                  </p>
                )}
                <FormMessage />
              </FormItem>
            )}
          />
          <FormField
            control={form.control}
            name="move_in_date"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Move-in date</FormLabel>
                <FormControl>
                  <Input type="date" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
          <FormField
            control={form.control}
            name="monthly_rent_rupees"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Monthly rent (₹)</FormLabel>
                <FormControl>
                  <Input
                    type="number"
                    min={1}
                    step={1}
                    {...field}
                    onChange={(e) => field.onChange(Number(e.target.value))}
                  />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
          <Button type="submit" className="w-full" disabled={form.formState.isSubmitting}>
            Save
          </Button>
        </form>
      </Form>
    </div>
  )
}
