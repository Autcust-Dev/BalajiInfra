import { useQuery, useQueryClient } from '@tanstack/react-query'
import { flexRender, tableFeatures, useTable, type ColumnDef } from '@tanstack/react-table'
import { Plus } from 'lucide-react'
import { Fragment, useState } from 'react'
import { Link } from 'react-router-dom'
import { toast } from 'sonner'
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
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
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
import { formatPaise } from '@/lib/validators'
import { supabase } from '@/lib/supabase'
import type { Tables } from '@/types/database.types'

type TenantRow = Tables<'tenants'> & {
  properties: { name: string } | null
  room_units: { capacity: number; rooms: { room_number: string } | null } | null
}
const PAGE_SIZE = 20

// v9's minimal feature set — this table is fully server-driven (search/filter/pagination
// all happen in the Supabase query below), so no client-side row model features are
// needed here, just column definitions + row rendering.
const features = tableFeatures({})

function buildColumns(
  selected: Set<string>,
  toggleSelected: (id: string) => void,
): ColumnDef<typeof features, TenantRow>[] {
  return [
    {
      id: 'select',
      header: '',
      cell: ({ row }) =>
        row.original.status === 'moved_out' ? (
          <Checkbox
            checked={selected.has(row.original.id)}
            onCheckedChange={() => toggleSelected(row.original.id)}
          />
        ) : null,
    },
    { accessorKey: 'full_name', header: 'Name' },
    {
      id: 'tenant_code',
      header: 'Tenant ID',
      cell: ({ row }) => row.original.tenant_code ?? '—',
    },
    { accessorKey: 'phone', header: 'Phone' },
    {
      id: 'room',
      header: 'Room',
      cell: ({ row }) => {
        const roomUnit = row.original.room_units
        if (!roomUnit) return '—'
        const roomNumber = roomUnit.rooms?.room_number ?? '—'
        return `${roomNumber} · ${sharingTypeLabel(roomUnit.capacity)}`
      },
    },
    {
      accessorKey: 'status',
      header: 'Status',
      cell: ({ row }) => (
        <Badge variant={row.original.status === 'active' ? 'secondary' : 'outline'}>
          {row.original.status}
        </Badge>
      ),
    },
    { accessorKey: 'kyc_status', header: 'KYC' },
    {
      accessorKey: 'monthly_rent_paise',
      header: 'Rent',
      cell: ({ row }) => `₹${formatPaise(row.original.monthly_rent_paise)}`,
    },
    {
      accessorKey: 'advance_paise',
      header: 'Advance',
      cell: ({ row }) => `₹${formatPaise(row.original.advance_paise)}`,
    },
    {
      id: 'actions',
      header: '',
      cell: ({ row }) => (
        <Button asChild variant="outline" size="sm">
          <Link to={`/tenants/${row.original.id}/edit`}>Edit</Link>
        </Button>
      ),
    },
  ]
}

export function TenantsPage() {
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<'all' | TenantRow['status']>('all')
  const [kycFilter, setKycFilter] = useState<'all' | TenantRow['kyc_status']>('all')
  const [page, setPage] = useState(0)
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [deleting, setDeleting] = useState(false)
  const queryClient = useQueryClient()

  const { data, isLoading } = useQuery({
    queryKey: ['tenants', search, statusFilter, kycFilter, page],
    queryFn: async () => {
      // Property alphabetical, then tenant id order within each property — tenants of the
      // same property land in adjacent rows, with a group header rendered per break below.
      let query = supabase
        .from('tenants')
        .select('*, properties(name), room_units(capacity, rooms(room_number))', {
          count: 'exact',
        })
        .order('name', { referencedTable: 'properties', ascending: true })
        .order('tenant_code', { ascending: true, nullsFirst: false })
        .range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE - 1)

      if (search.trim()) {
        query = query.or(
          `full_name.ilike.%${search}%,phone.ilike.%${search}%,tenant_code.ilike.%${search}%`,
        )
      }
      if (statusFilter !== 'all') query = query.eq('status', statusFilter)
      if (kycFilter !== 'all') query = query.eq('kyc_status', kycFilter)

      const { data, error, count } = await query
      if (error) throw error
      return { rows: data as TenantRow[], total: count ?? 0 }
    },
  })

  function toggleSelected(id: string) {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  async function bulkDelete() {
    setDeleting(true)
    const ids = Array.from(selected)
    let failed = 0
    for (const id of ids) {
      const { error } = await supabase.from('tenants').delete().eq('id', id)
      if (error) failed += 1
    }
    setDeleting(false)
    setSelected(new Set())
    await queryClient.invalidateQueries({ queryKey: ['tenants'] })
    if (failed > 0) {
      toast.error(
        `${ids.length - failed} deleted, ${failed} could not be deleted — they still have an unpaid due. Settle or cancel it first, then delete again.`,
      )
    } else {
      toast.success(`${ids.length} tenant${ids.length === 1 ? '' : 's'} deleted`)
    }
  }

  const columns = buildColumns(selected, toggleSelected)
  const table = useTable({
    features,
    data: data?.rows ?? [],
    columns,
  })

  const totalPages = data ? Math.max(1, Math.ceil(data.total / PAGE_SIZE)) : 1

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-foreground text-xl font-medium">Tenants</h1>
        <Button asChild size="sm">
          <Link to="/tenants/new">
            <Plus className="size-4" />
            Add tenant
          </Link>
        </Button>
      </div>

      <div className="flex flex-wrap gap-2">
        <Input
          placeholder="Search name, phone, or tenant ID…"
          value={search}
          onChange={(e) => {
            setSearch(e.target.value)
            setPage(0)
          }}
          className="max-w-xs"
        />
        <Select
          value={statusFilter}
          onValueChange={(v) => {
            setStatusFilter(v as typeof statusFilter)
            setPage(0)
          }}
        >
          <SelectTrigger className="w-40">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All statuses</SelectItem>
            <SelectItem value="active">Active</SelectItem>
            <SelectItem value="moved_out">Moved out</SelectItem>
          </SelectContent>
        </Select>
        <Select
          value={kycFilter}
          onValueChange={(v) => {
            setKycFilter(v as typeof kycFilter)
            setPage(0)
          }}
        >
          <SelectTrigger className="w-44">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All KYC statuses</SelectItem>
            <SelectItem value="not_started">Not started</SelectItem>
            <SelectItem value="submitted">Submitted</SelectItem>
            <SelectItem value="approved">Approved</SelectItem>
            <SelectItem value="rejected">Rejected</SelectItem>
          </SelectContent>
        </Select>
      </div>

      {selected.size > 0 && (
        <div className="bg-muted flex items-center justify-between rounded-md p-2">
          <span className="text-sm">{selected.size} selected</span>
          <AlertDialog>
            <AlertDialogTrigger asChild>
              <Button size="sm" variant="destructive" disabled={deleting}>
                Delete selected
              </Button>
            </AlertDialogTrigger>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>Delete {selected.size} tenant(s)?</AlertDialogTitle>
                <AlertDialogDescription>
                  This permanently deletes each selected tenant along with their dues,
                  payments, and fines — only tenants with no unpaid due will actually be
                  deleted; this cannot be undone. Any with an unpaid due are skipped and
                  reported back, not deleted.
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel>Cancel</AlertDialogCancel>
                <AlertDialogAction onClick={() => void bulkDelete()}>Delete</AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        </div>
      )}

      <Table>
        <TableHeader>
          {table.getHeaderGroups().map((headerGroup) => (
            <TableRow key={headerGroup.id}>
              {headerGroup.headers.map((header) => (
                <TableHead key={header.id}>
                  {flexRender(header.column.columnDef.header, header.getContext())}
                </TableHead>
              ))}
            </TableRow>
          ))}
        </TableHeader>
        <TableBody>
          {isLoading && (
            <TableRow>
              <TableCell colSpan={columns.length}>Loading…</TableCell>
            </TableRow>
          )}
          {data?.rows.length === 0 && (
            <TableRow>
              <TableCell colSpan={columns.length} className="text-muted-foreground">
                No tenants match.
              </TableCell>
            </TableRow>
          )}
          {table.getRowModel().rows.map((row, index) => {
            const propertyName = row.original.properties?.name ?? 'Unassigned'
            const previousPropertyName =
              index > 0 ? (data?.rows[index - 1]?.properties?.name ?? 'Unassigned') : null
            const showGroupHeader = propertyName !== previousPropertyName

            return (
              <Fragment key={row.id}>
                {showGroupHeader && (
                  <TableRow key={`${propertyName}-header`} className="bg-muted/50 hover:bg-muted/50">
                    <TableCell colSpan={columns.length} className="text-sm font-medium">
                      {propertyName}
                    </TableCell>
                  </TableRow>
                )}
                <TableRow>
                  {row.getAllCells().map((cell) => (
                    <TableCell key={cell.id}>
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </TableCell>
                  ))}
                </TableRow>
              </Fragment>
            )
          })}
        </TableBody>
      </Table>

      <div className="text-muted-foreground flex items-center justify-between text-sm">
        <span>
          Page {page + 1} of {totalPages}
        </span>
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="sm"
            disabled={page === 0}
            onClick={() => setPage((p) => p - 1)}
          >
            Previous
          </Button>
          <Button
            variant="outline"
            size="sm"
            disabled={page + 1 >= totalPages}
            onClick={() => setPage((p) => p + 1)}
          >
            Next
          </Button>
        </div>
      </div>
    </div>
  )
}
