import { zodResolver } from '@hookform/resolvers/zod'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Plus } from 'lucide-react'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { Link, useParams } from 'react-router-dom'
import { toast } from 'sonner'
import { z } from 'zod'
import { Badge } from '@/components/ui/badge'
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
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { supabase } from '@/lib/supabase'
import type { Tables } from '@/types/database.types'

const roomSchema = z.object({
  room_number: z.string().min(1, 'Room number is required'),
  capacity: z.number().int().positive('Capacity must be at least 1'),
})
type RoomValues = z.infer<typeof roomSchema>

function useRoomsWithOccupancy(propertyId: string) {
  return useQuery({
    queryKey: ['rooms', propertyId],
    queryFn: async () => {
      const [roomsRes, tenantsRes] = await Promise.all([
        supabase.from('rooms').select('*').eq('property_id', propertyId).order('room_number'),
        supabase
          .from('tenants')
          .select('room_id')
          .eq('property_id', propertyId)
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

function RoomFormDialog({
  propertyId,
  room,
  trigger,
}: {
  propertyId: string
  room?: Tables<'rooms'>
  trigger: React.ReactNode
}) {
  const [open, setOpen] = useState(false)
  const queryClient = useQueryClient()
  const form = useForm<RoomValues>({
    resolver: zodResolver(roomSchema),
    defaultValues: { room_number: room?.room_number ?? '', capacity: room?.capacity ?? 1 },
  })

  async function onSubmit(values: RoomValues) {
    const { error } = room
      ? await supabase.from('rooms').update(values).eq('id', room.id)
      : await supabase.from('rooms').insert({ ...values, property_id: propertyId })
    if (error) {
      toast.error(
        error.code === '23505'
          ? 'A room with that number already exists in this property.'
          : error.message,
      )
      return
    }
    toast.success(room ? 'Room updated' : 'Room added')
    await queryClient.invalidateQueries({ queryKey: ['rooms', propertyId] })
    setOpen(false)
    form.reset()
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>{trigger}</DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{room ? 'Edit room' : 'Add room'}</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="room_number"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Room number</FormLabel>
                  <FormControl>
                    <Input {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="capacity"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Capacity</FormLabel>
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
            <Button type="submit" className="w-full" disabled={form.formState.isSubmitting}>
              Save
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  )
}

export function PropertyRoomsPage() {
  const { propertyId } = useParams<{ propertyId: string }>()
  const queryClient = useQueryClient()
  const { data: rooms, isLoading } = useRoomsWithOccupancy(propertyId!)

  async function deleteRoom(room: Tables<'rooms'>) {
    const { error } = await supabase.from('rooms').delete().eq('id', room.id)
    if (error) {
      toast.error(
        error.code === '23503'
          ? 'Cannot delete a room with tenants. Move the tenants out or reassign them first.'
          : error.message,
      )
      return
    }
    toast.success('Room deleted')
    await queryClient.invalidateQueries({ queryKey: ['rooms', propertyId] })
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <Link to="/properties" className="text-muted-foreground text-sm hover:underline">
            ← Properties
          </Link>
          <h1 className="text-foreground text-xl font-medium">Rooms</h1>
        </div>
        <RoomFormDialog
          propertyId={propertyId!}
          trigger={
            <Button size="sm">
              <Plus className="size-4" />
              Add room
            </Button>
          }
        />
      </div>

      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Room</TableHead>
            <TableHead>Occupancy</TableHead>
            <TableHead className="w-40" />
          </TableRow>
        </TableHeader>
        <TableBody>
          {isLoading && (
            <TableRow>
              <TableCell colSpan={3}>Loading…</TableCell>
            </TableRow>
          )}
          {rooms?.length === 0 && (
            <TableRow>
              <TableCell colSpan={3} className="text-muted-foreground">
                No rooms yet.
              </TableCell>
            </TableRow>
          )}
          {rooms?.map((room) => {
            const full = room.occupancy >= room.capacity
            return (
              <TableRow key={room.id}>
                <TableCell>{room.room_number}</TableCell>
                <TableCell>
                  <Badge variant={full ? 'destructive' : 'secondary'}>
                    {room.occupancy}/{room.capacity}
                    {full ? ' · full' : ''}
                  </Badge>
                </TableCell>
                <TableCell className="flex justify-end gap-2">
                  <RoomFormDialog
                    propertyId={propertyId!}
                    room={room}
                    trigger={
                      <Button variant="outline" size="sm">
                        Edit
                      </Button>
                    }
                  />
                  <Button variant="outline" size="sm" onClick={() => void deleteRoom(room)}>
                    Delete
                  </Button>
                </TableCell>
              </TableRow>
            )
          })}
        </TableBody>
      </Table>
    </div>
  )
}
