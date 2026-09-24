import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { toast } from 'sonner'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { supabase } from '@/lib/supabase'
import type { Database } from '@/types/database.types'

type KycStatus = Database['public']['Enums']['kyc_status']

const TABS: { value: KycStatus; label: string }[] = [
  { value: 'not_started', label: 'Yet to submit' },
  { value: 'submitted', label: 'Pending review' },
  { value: 'rejected', label: 'Rejected' },
  { value: 'approved', label: 'Approved' },
]

function useKycQueue(status: KycStatus) {
  return useQuery({
    queryKey: ['kyc-queue', status],
    queryFn: async () => {
      if (status === 'not_started') {
        // No kyc_submissions row exists at all for these tenants — list from tenants.
        const { data, error } = await supabase
          .from('tenants')
          .select('id, full_name, phone')
          .eq('kyc_status', 'not_started')
          .eq('status', 'active')
          .order('full_name')
        if (error) throw error
        return data.map((t) => ({
          submissionId: null as string | null,
          tenantId: t.id,
          tenantName: t.full_name,
          tenantPhone: t.phone,
          submittedAt: null as string | null,
        }))
      }

      const { data, error } = await supabase
        .from('kyc_submissions')
        .select('id, tenant_id, submitted_at, tenants(full_name, phone)')
        .eq('status', status)
        .order('submitted_at', { ascending: false })
      if (error) throw error
      return data.map((s) => ({
        submissionId: s.id as string | null,
        tenantId: s.tenant_id,
        tenantName: s.tenants?.full_name ?? '(unknown)',
        tenantPhone: s.tenants?.phone ?? '',
        submittedAt: s.submitted_at,
      }))
    },
  })
}

export function KycQueuePage() {
  const [tab, setTab] = useState<KycStatus>('submitted')
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const { data: rows, isLoading } = useKycQueue(tab)
  const queryClient = useQueryClient()

  function toggleSelected(id: string) {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  async function bulkDownload() {
    const ids = Array.from(selected)
    for (const submissionId of ids) {
      for (const file of ['aadhaar', 'selfie'] as const) {
        const { data, error } = await supabase.functions.invoke('kyc-file-url', {
          body: { submission_id: submissionId, file, action: 'download' },
        })
        if (error || !data?.url) {
          toast.error(`Failed to get a download link for one file — stopped.`)
          return
        }
        window.open(data.url, '_blank')
      }
    }
    setSelected(new Set())
  }

  async function deleteSubmission(submissionId: string) {
    const { error } = await supabase.functions.invoke('kyc-delete', {
      body: { submission_id: submissionId },
    })
    if (error) {
      toast.error('Failed to delete submission')
      return
    }
    toast.success('Submission deleted — tenant can resubmit')
    await queryClient.invalidateQueries({ queryKey: ['kyc-queue'] })
  }

  return (
    <div className="space-y-4">
      <h1 className="text-foreground text-xl font-medium">KYC</h1>

      <Tabs value={tab} onValueChange={(v) => setTab(v as KycStatus)}>
        <TabsList>
          {TABS.map((t) => (
            <TabsTrigger key={t.value} value={t.value}>
              {t.label}
            </TabsTrigger>
          ))}
        </TabsList>
      </Tabs>

      {selected.size > 0 && (
        <div className="bg-muted flex items-center justify-between rounded-md p-2">
          <span className="text-sm">{selected.size} selected</span>
          <Button size="sm" variant="outline" onClick={() => void bulkDownload()}>
            Download selected
          </Button>
        </div>
      )}

      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="w-10" />
            <TableHead>Tenant</TableHead>
            <TableHead>Phone</TableHead>
            <TableHead>Submitted</TableHead>
            <TableHead className="w-56" />
          </TableRow>
        </TableHeader>
        <TableBody>
          {isLoading && (
            <TableRow>
              <TableCell colSpan={5}>Loading…</TableCell>
            </TableRow>
          )}
          {rows?.length === 0 && (
            <TableRow>
              <TableCell colSpan={5} className="text-muted-foreground">
                Nothing here.
              </TableCell>
            </TableRow>
          )}
          {rows?.map((row) => (
            <TableRow key={row.tenantId}>
              <TableCell>
                {row.submissionId && (
                  <Checkbox
                    checked={selected.has(row.submissionId)}
                    onCheckedChange={() => toggleSelected(row.submissionId!)}
                  />
                )}
              </TableCell>
              <TableCell>{row.tenantName}</TableCell>
              <TableCell className="text-muted-foreground">{row.tenantPhone}</TableCell>
              <TableCell>
                {row.submittedAt ? new Date(row.submittedAt).toLocaleDateString('en-IN') : '—'}
              </TableCell>
              <TableCell className="flex justify-end gap-2">
                {row.submissionId ? (
                  <>
                    <Button asChild variant="outline" size="sm">
                      <Link to={`/kyc/${row.submissionId}`}>Review</Link>
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => void deleteSubmission(row.submissionId!)}
                    >
                      Delete
                    </Button>
                  </>
                ) : (
                  <Badge variant="outline">No submission yet</Badge>
                )}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  )
}
