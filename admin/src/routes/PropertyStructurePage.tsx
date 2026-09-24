import { zodResolver } from '@hookform/resolvers/zod'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Plus } from 'lucide-react'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { Link, useParams } from 'react-router-dom'
import { toast } from 'sonner'
import { z } from 'zod'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
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
import { supabase } from '@/lib/supabase'
import type { Tables } from '@/types/database.types'

const nameSchema = z.object({ name: z.string().min(1, 'Name is required') })
type NameValues = z.infer<typeof nameSchema>

function useStructure(propertyId: string) {
  return useQuery({
    queryKey: ['property-structure', propertyId],
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

function AddFloorDialog({ propertyId }: { propertyId: string }) {
  const [open, setOpen] = useState(false)
  const queryClient = useQueryClient()
  const form = useForm<NameValues>({
    resolver: zodResolver(nameSchema),
    defaultValues: { name: '' },
  })

  async function onSubmit(values: NameValues) {
    const { error } = await supabase
      .from('floors')
      .insert({ property_id: propertyId, name: values.name })
    if (error) {
      toast.error(error.code === '23505' ? 'A floor with that name already exists.' : error.message)
      return
    }
    toast.success('Floor added')
    await queryClient.invalidateQueries({ queryKey: ['property-structure', propertyId] })
    setOpen(false)
    form.reset()
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm">
          <Plus className="size-4" />
          Add floor
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Add floor</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="name"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Name</FormLabel>
                  <FormControl>
                    <Input placeholder="e.g. Floor 1, Ground" {...field} />
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

function AddBlockDialog({ floorId, propertyId }: { floorId: string; propertyId: string }) {
  const [open, setOpen] = useState(false)
  const queryClient = useQueryClient()
  const form = useForm<NameValues>({
    resolver: zodResolver(nameSchema),
    defaultValues: { name: '' },
  })

  async function onSubmit(values: NameValues) {
    const { error } = await supabase.from('blocks').insert({ floor_id: floorId, name: values.name })
    if (error) {
      toast.error(
        error.code === '23505'
          ? 'A block with that name already exists on this floor.'
          : error.message,
      )
      return
    }
    toast.success('Block added')
    await queryClient.invalidateQueries({ queryKey: ['property-structure', propertyId] })
    setOpen(false)
    form.reset()
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm" variant="outline">
          <Plus className="size-4" />
          Add block
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Add block</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="name"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Name</FormLabel>
                  <FormControl>
                    <Input placeholder="e.g. F1, F2" {...field} />
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

type FloorWithBlocks = Tables<'floors'> & { blocks: Tables<'blocks'>[] }

export function PropertyStructurePage() {
  const { propertyId } = useParams<{ propertyId: string }>()
  const { data: floors, isLoading } = useStructure(propertyId!)

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <Link to="/properties" className="text-muted-foreground text-sm hover:underline">
            ← Properties
          </Link>
          <h1 className="text-foreground text-xl font-medium">Floors &amp; blocks</h1>
        </div>
        <AddFloorDialog propertyId={propertyId!} />
      </div>

      {isLoading && <p className="text-muted-foreground text-sm">Loading…</p>}
      {floors?.length === 0 && (
        <p className="text-muted-foreground text-sm">
          No floors yet. Add one, then add blocks within it — rooms are assigned to a block from the
          Rooms page.
        </p>
      )}

      <div className="space-y-3">
        {floors?.map((floor: FloorWithBlocks) => (
          <Card key={floor.id}>
            <CardHeader className="flex-row items-center justify-between space-y-0">
              <CardTitle className="text-base">{floor.name}</CardTitle>
              <AddBlockDialog floorId={floor.id} propertyId={propertyId!} />
            </CardHeader>
            <CardContent>
              {floor.blocks.length === 0 ? (
                <p className="text-muted-foreground text-sm">No blocks on this floor yet.</p>
              ) : (
                <div className="flex flex-wrap gap-2">
                  {floor.blocks.map((block) => (
                    <span
                      key={block.id}
                      className="bg-secondary text-secondary-foreground rounded-md px-2 py-1 text-sm"
                    >
                      {block.name}
                    </span>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  )
}
