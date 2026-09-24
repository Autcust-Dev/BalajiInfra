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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { sharingTypeLabel } from '@/lib/rooms'
import { supabase } from '@/lib/supabase'
import type { Tables } from '@/types/database.types'

const NO_BLOCK = '__unassigned__'
const SHARING_CAPACITIES = [1, 2, 3]

const roomSchema = z.object({
  room_number: z.string().min(1, 'Room number is required'),
  block_id: z.string(),
})
type RoomValues = z.infer<typeof roomSchema>

const unitSchema = z.object({
  capacity: z.string().min(1, 'Select a sharing type'),
})
type UnitValues = z.infer<typeof unitSchema>

function useRoomsWithUnits(propertyId: string) {
  return useQuery({
    queryKey: ['rooms', propertyId],
    queryFn: async () => {
      const [roomsRes, blocksRes] = await Promise.all([
        supabase.from('rooms').select('*').eq('property_id', propertyId).order('room_number'),
        supabase
          .from('blocks')
          .select('id, name, floors!inner(id, name, property_id)')
          .eq('floors.property_id', propertyId),
      ])
      if (roomsRes.error) throw roomsRes.error
      if (blocksRes.error) throw blocksRes.error

      const roomIds = roomsRes.data.map((r) => r.id)
      const unitsRes =
        roomIds.length === 0
          ? { data: [], error: null }
          : await supabase.from('room_units').select('*').in('room_id', roomIds).order('capacity')
      if (unitsRes.error) throw unitsRes.error

      const unitIds = unitsRes.data.map((u) => u.id)
      const tenantsRes =
        unitIds.length === 0
          ? { data: [], error: null }
          : await supabase
              .from('tenants')
              .select('room_unit_id')
              .eq('status', 'active')
              .in('room_unit_id', unitIds)
      if (tenantsRes.error) throw tenantsRes.error

      const occupancyByUnit = new Map<string, number>()
      for (const t of tenantsRes.data) {
        occupancyByUnit.set(t.room_unit_id, (occupancyByUnit.get(t.room_unit_id) ?? 0) + 1)
      }
      const blockLabelById = new Map(
        blocksRes.data.map((b) => [b.id, `${b.floors.name} / ${b.name}`]),
      )

      return roomsRes.data.map((room) => ({
        ...room,
        blockLabel: room.block_id ? (blockLabelById.get(room.block_id) ?? 'Unknown block') : null,
        units: unitsRes.data
          .filter((u) => u.room_id === room.id)
          .map((u) => ({ ...u, occupancy: occupancyByUnit.get(u.id) ?? 0 })),
      }))
    },
  })
}

function useFloorsAndBlocks(propertyId: string) {
  return useQuery({
    queryKey: ['floors-and-blocks', propertyId],
    queryFn: async () => {
      const { data: floors, error: floorsError } = await supabase
        .from('floors')
        .select('*')
        .eq('property_id', propertyId)
        .order('display_order')
        .order('name')
      if (floorsError) throw floorsError

      const { data: blocks, error: blocksError } = await supabase
        .from('blocks')
        .select('*')
        .in(
          'floor_id',
          floors.map((f) => f.id),
        )
        .order('display_order')
        .order('name')
      if (blocksError) throw blocksError

      return floors.map((floor) => ({
        ...floor,
        blocks: blocks.filter((b) => b.floor_id === floor.id),
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
  const { data: floors } = useFloorsAndBlocks(propertyId)
  const form = useForm<RoomValues>({
    resolver: zodResolver(roomSchema),
    defaultValues: {
      room_number: room?.room_number ?? '',
      block_id: room?.block_id ?? NO_BLOCK,
    },
  })

  async function onSubmit(values: RoomValues) {
    const payload = {
      room_number: values.room_number,
      block_id: values.block_id === NO_BLOCK ? null : values.block_id,
    }
    const { error } = room
      ? await supabase.from('rooms').update(payload).eq('id', room.id)
      : await supabase.from('rooms').insert({ ...payload, property_id: propertyId })
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
              name="block_id"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Block (optional)</FormLabel>
                  <Select value={field.value} onValueChange={field.onChange}>
                    <FormControl>
                      <SelectTrigger className="w-full">
                        <SelectValue />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      <SelectItem value={NO_BLOCK}>Unassigned</SelectItem>
                      {floors?.flatMap((floor) =>
                        floor.blocks.map((block) => (
                          <SelectItem key={block.id} value={block.id}>
                            {floor.name} / {block.name}
                          </SelectItem>
                        )),
                      )}
                    </SelectContent>
                  </Select>
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

function AddUnitDialog({
  propertyId,
  roomId,
  existingCapacities,
}: {
  propertyId: string
  roomId: string
  existingCapacities: number[]
}) {
  const [open, setOpen] = useState(false)
  const queryClient = useQueryClient()
  const availableCapacities = SHARING_CAPACITIES.filter((c) => !existingCapacities.includes(c))
  const form = useForm<UnitValues>({
    resolver: zodResolver(unitSchema),
    defaultValues: { capacity: '' },
  })

  async function onSubmit(values: UnitValues) {
    const { error } = await supabase
      .from('room_units')
      .insert({ room_id: roomId, capacity: Number(values.capacity) })
    if (error) {
      toast.error(
        error.code === '23505'
          ? 'This room already has a unit of that sharing type.'
          : error.message,
      )
      return
    }
    toast.success('Sharing unit added')
    await queryClient.invalidateQueries({ queryKey: ['rooms', propertyId] })
    setOpen(false)
    form.reset()
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        setOpen(next)
        if (!next) form.reset()
      }}
    >
      <DialogTrigger asChild>
        <Button size="sm" variant="outline" disabled={availableCapacities.length === 0}>
          <Plus className="size-4" />
          Add sharing unit
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Add sharing unit</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="capacity"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Sharing type</FormLabel>
                  <Select value={field.value} onValueChange={field.onChange}>
                    <FormControl>
                      <SelectTrigger className="w-full">
                        <SelectValue placeholder="Select a sharing type" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {availableCapacities.map((c) => (
                        <SelectItem key={c} value={String(c)}>
                          {sharingTypeLabel(c)}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
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
  const { data: rooms, isLoading } = useRoomsWithUnits(propertyId!)

  async function deleteRoom(room: Tables<'rooms'>) {
    const { error } = await supabase.from('rooms').delete().eq('id', room.id)
    if (error) {
      toast.error(
        error.code === '23503'
          ? 'Cannot delete a room with sharing units. Delete its units first.'
          : error.message,
      )
      return
    }
    toast.success('Room deleted')
    await queryClient.invalidateQueries({ queryKey: ['rooms', propertyId] })
  }

  async function deleteUnit(unitId: string) {
    const { error } = await supabase.from('room_units').delete().eq('id', unitId)
    if (error) {
      toast.error(
        error.code === '23503'
          ? 'Cannot delete a unit with tenants. Move the tenant out or reassign them first.'
          : error.message,
      )
      return
    }
    toast.success('Sharing unit deleted')
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

      {isLoading && <p className="text-muted-foreground text-sm">Loading…</p>}
      {rooms?.length === 0 && <p className="text-muted-foreground text-sm">No rooms yet.</p>}

      <div className="space-y-3">
        {rooms?.map((room) => (
          <div key={room.id} className="rounded-md border p-4">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="font-medium">Room {room.room_number}</h2>
                <p className="text-muted-foreground text-xs">{room.blockLabel ?? 'Unassigned'}</p>
              </div>
              <div className="flex gap-2">
                <AddUnitDialog
                  propertyId={propertyId!}
                  roomId={room.id}
                  existingCapacities={room.units.map((u) => u.capacity)}
                />
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
              </div>
            </div>

            {room.units.length === 0 ? (
              <p className="text-muted-foreground mt-3 text-sm">
                No sharing units yet — add one to start assigning tenants here.
              </p>
            ) : (
              <div className="mt-3 flex flex-wrap gap-2">
                {room.units.map((unit) => {
                  const full = unit.occupancy >= unit.capacity
                  return (
                    <div
                      key={unit.id}
                      className="flex items-center gap-2 rounded-md border px-3 py-2 text-sm"
                    >
                      <span>{sharingTypeLabel(unit.capacity)}</span>
                      <Badge variant={full ? 'destructive' : 'secondary'}>
                        {unit.occupancy}/{unit.capacity}
                        {full ? ' · full' : ''}
                      </Badge>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => void deleteUnit(unit.id)}
                        disabled={unit.occupancy > 0}
                      >
                        Delete
                      </Button>
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}
