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
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { useAuth } from '@/lib/auth-context'
import { supabase } from '@/lib/supabase'
import type { Tables } from '@/types/database.types'

const propertySchema = z.object({
  name: z.string().min(1, 'Name is required'),
  address: z.string().min(1, 'Address is required'),
})
type PropertyValues = z.infer<typeof propertySchema>

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

function PropertyFormDialog({
  property,
  trigger,
}: {
  property?: Tables<'properties'>
  trigger: React.ReactNode
}) {
  const [open, setOpen] = useState(false)
  const queryClient = useQueryClient()
  const form = useForm<PropertyValues>({
    resolver: zodResolver(propertySchema),
    defaultValues: { name: property?.name ?? '', address: property?.address ?? '' },
  })

  async function onSubmit(values: PropertyValues) {
    const { error } = property
      ? await supabase.from('properties').update(values).eq('id', property.id)
      : await supabase.from('properties').insert(values)
    if (error) {
      toast.error(error.message)
      return
    }
    toast.success(property ? 'Property updated' : 'Property added')
    await queryClient.invalidateQueries({ queryKey: ['properties'] })
    setOpen(false)
    form.reset()
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>{trigger}</DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{property ? 'Edit property' : 'Add property'}</DialogTitle>
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
                    <Input {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="address"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Address</FormLabel>
                  <FormControl>
                    <Input {...field} />
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

export function PropertiesPage() {
  const { adminProfile } = useAuth()
  const isOwner = adminProfile?.role === 'owner'
  const { data: properties, isLoading } = usePropertiesQuery()

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-foreground text-xl font-medium">Properties</h1>
        {isOwner && (
          <PropertyFormDialog
            trigger={
              <Button size="sm">
                <Plus className="size-4" />
                Add property
              </Button>
            }
          />
        )}
      </div>

      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Name</TableHead>
            <TableHead>Address</TableHead>
            <TableHead className="w-32" />
          </TableRow>
        </TableHeader>
        <TableBody>
          {isLoading && (
            <TableRow>
              <TableCell colSpan={3}>Loading…</TableCell>
            </TableRow>
          )}
          {properties?.length === 0 && (
            <TableRow>
              <TableCell colSpan={3} className="text-muted-foreground">
                No properties yet.
              </TableCell>
            </TableRow>
          )}
          {properties?.map((property) => (
            <TableRow key={property.id}>
              <TableCell>{property.name}</TableCell>
              <TableCell>{property.address}</TableCell>
              <TableCell className="flex justify-end gap-2">
                <Button asChild variant="outline" size="sm">
                  <Link to={`/properties/${property.id}/structure`}>Floors &amp; blocks</Link>
                </Button>
                <Button asChild variant="outline" size="sm">
                  <Link to={`/properties/${property.id}/rooms`}>Rooms</Link>
                </Button>
                {isOwner && (
                  <PropertyFormDialog
                    property={property}
                    trigger={
                      <Button variant="outline" size="sm">
                        Edit
                      </Button>
                    }
                  />
                )}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  )
}
