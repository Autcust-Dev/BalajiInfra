import { useQuery, useQueryClient } from '@tanstack/react-query'
import { flexRender, tableFeatures, useTable, type ColumnDef } from '@tanstack/react-table'
import { Plus } from 'lucide-react'
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { toast } from 'sonner'
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
import { formatPaise } from '@/lib/validators'
import { supabase } from '@/lib/supabase'
import type { Tables } from '@/types/database.types'

type Tenant = Tables<'tenants'>
const PAGE_SIZE = 20

// v9's minimal feature set — this table is fully server-driven (search/filter/pagination
// all happen in the Supabase query below), so no client-side row model features are
// needed here, just column definitions + row rendering.
const features = tableFeatures({})

function buildColumns(
  selected: Set<string>,
  toggleSelected: (id: string) => void,
): ColumnDef<typeof features, Tenant>[] {
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
    { accessorKey: 'phone', header: 'Phone' },
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
  const [statusFilter, setStatusFilter] = useState<'all' | Tenant['status']>('all')
  const [kycFilter, setKycFilter] = useState<'all' | Tenant['kyc_status']>('all')
  const [page, setPage] = useState(0)
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [deleting, setDeleting] = useState(false)
  const queryClient = useQueryClient()

  const { data, isLoading } = useQuery({
    queryKey: ['tenants', search, statusFilter, kycFilter, page],
    queryFn: async () => {
      let query = supabase
        .from('tenants')
        .select('*', { count: 'exact' })
        .order('full_name')
        .range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE - 1)

      if (search.trim()) {
        query = query.or(`full_name.ilike.%${search}%,phone.ilike.%${search}%`)
      }
      if (statusFilter !== 'all') query = query.eq('status', statusFilter)
      if (kycFilter !== 'all') query = query.eq('kyc_status', kycFilter)

      const { data, error, count } = await query
      if (error) throw error
      return { rows: data, total: count ?? 0 }
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
        `${ids.length - failed} deleted, ${failed} could not be deleted — they likely have dues or payment history.`,
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
          placeholder="Search name or phone…"
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
          <Button
            size="sm"
            variant="destructive"
            onClick={() => void bulkDelete()}
            disabled={deleting}
          >
            Delete selected
          </Button>
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
          {table.getRowModel().rows.map((row) => (
            <TableRow key={row.id}>
              {row.getAllCells().map((cell) => (
                <TableCell key={cell.id}>
                  {flexRender(cell.column.columnDef.cell, cell.getContext())}
                </TableCell>
              ))}
            </TableRow>
          ))}
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
