import { zodResolver } from '@hookform/resolvers/zod'
import { useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { toast } from 'sonner'
import { z } from 'zod'
import { Button } from '@/components/ui/button'
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
import { Textarea } from '@/components/ui/textarea'
import { useAuth } from '@/lib/auth-context'
import { supabase } from '@/lib/supabase'

const rejectSchema = z.object({
  rejection_reason: z.string().min(1, 'A reason is required — the tenant will see this exact text'),
})
type RejectValues = z.infer<typeof rejectSchema>

function useSubmission(submissionId: string) {
  return useQuery({
    queryKey: ['kyc-submission', submissionId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('kyc_submissions')
        .select('*, tenants(full_name, phone)')
        .eq('id', submissionId)
        .single()
      if (error) throw error
      return data
    },
  })
}

function DocumentPreview({
  submissionId,
  file,
  label,
}: {
  submissionId: string
  file: 'aadhaar' | 'selfie'
  label: string
}) {
  const [url, setUrl] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  async function loadPreview() {
    setLoading(true)
    const { data, error } = await supabase.functions.invoke('kyc-file-url', {
      body: { submission_id: submissionId, file, action: 'view' },
    })
    setLoading(false)
    if (error || !data?.url) {
      toast.error(`Failed to load ${label.toLowerCase()}`)
      return
    }
    setUrl(data.url)
  }

  async function download() {
    const { data, error } = await supabase.functions.invoke('kyc-file-url', {
      body: { submission_id: submissionId, file, action: 'download' },
    })
    if (error || !data?.url) {
      toast.error(`Failed to download ${label.toLowerCase()}`)
      return
    }
    window.open(data.url, '_blank')
  }

  return (
    <div className="space-y-2 rounded-md border p-3">
      <div className="flex items-center justify-between">
        <span className="text-sm font-medium">{label}</span>
        <div className="flex gap-2">
          <Button size="sm" variant="outline" onClick={() => void loadPreview()} disabled={loading}>
            {url ? 'Refresh' : 'View'}
          </Button>
          <Button size="sm" variant="outline" onClick={() => void download()}>
            Download
          </Button>
        </div>
      </div>
      {url && (
        // Signed URL, valid <= 60s (CLAUDE.md §4 rule 20) — expect this to go stale quickly.
        <img src={url} alt={label} className="max-h-80 rounded-md border object-contain" />
      )}
    </div>
  )
}

function RejectDialog({ submissionId }: { submissionId: string }) {
  const [open, setOpen] = useState(false)
  const navigate = useNavigate()
  const form = useForm<RejectValues>({
    resolver: zodResolver(rejectSchema),
    defaultValues: { rejection_reason: '' },
  })

  async function onSubmit(values: RejectValues) {
    const { error } = await supabase
      .from('kyc_submissions')
      .update({ status: 'rejected', rejection_reason: values.rejection_reason })
      .eq('id', submissionId)
    if (error) {
      toast.error(error.message)
      return
    }
    toast.success('Submission rejected — tenant can resubmit')
    navigate('/kyc')
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="destructive">Reject</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Reject KYC submission</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="rejection_reason"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Reason (shown to the tenant, word it clearly)</FormLabel>
                  <FormControl>
                    <Textarea
                      rows={4}
                      placeholder="e.g. Aadhaar photo is blurry — please retake and resubmit."
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <DialogFooter>
              <Button type="submit" variant="destructive" disabled={form.formState.isSubmitting}>
                Confirm reject
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  )
}

export function KycReviewPage() {
  const { submissionId } = useParams<{ submissionId: string }>()
  const navigate = useNavigate()
  const { adminProfile } = useAuth()
  const { data: submission, isLoading } = useSubmission(submissionId!)

  async function approve() {
    if (!submission || !adminProfile) return
    const { error } = await supabase
      .from('kyc_submissions')
      .update({
        status: 'approved',
        reviewed_by: adminProfile.id,
        reviewed_at: new Date().toISOString(),
      })
      .eq('id', submission.id)
    if (error) {
      toast.error(error.message)
      return
    }
    toast.success('Approved')
    navigate('/kyc')
  }

  if (isLoading || !submission) {
    return <p className="text-muted-foreground text-sm">Loading…</p>
  }

  return (
    <div className="max-w-lg space-y-4">
      <Link to="/kyc" className="text-muted-foreground text-sm hover:underline">
        ← KYC
      </Link>
      <div>
        <h1 className="text-foreground text-xl font-medium">{submission.tenants?.full_name}</h1>
        <p className="text-muted-foreground text-sm">
          {submission.tenants?.phone} · Aadhaar ending {submission.aadhaar_last4} · Status:{' '}
          {submission.status}
        </p>
        {submission.status === 'rejected' && submission.rejection_reason && (
          <p className="text-destructive mt-1 text-sm">
            Previous rejection reason: {submission.rejection_reason}
          </p>
        )}
      </div>

      <DocumentPreview submissionId={submission.id} file="aadhaar" label="Masked Aadhaar" />
      <DocumentPreview submissionId={submission.id} file="selfie" label="Selfie" />

      {submission.status === 'submitted' && (
        <div className="flex gap-2">
          <Button onClick={() => void approve()}>Approve</Button>
          <RejectDialog submissionId={submission.id} />
        </div>
      )}
    </div>
  )
}
