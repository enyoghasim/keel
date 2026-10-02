import { useMutation } from '@tanstack/react-query'
import type { Company, Envelope } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'
import { uploadFile } from '../../lib/direct-upload'

export function UploadForm({ onAssembled }: { onAssembled: (companyId: string) => void }) {
  const [name, setName] = useState('')
  const [rosterCsv, setRosterCsv] = useState<File | null>(null)
  const [handbook, setHandbook] = useState<File | null>(null)

  const assemble = useMutation({
    mutationFn: async () => {
      const [rosterSignedId, handbookSignedId] = await Promise.all([
        uploadFile(rosterCsv!),
        handbook ? uploadFile(handbook) : Promise.resolve(undefined),
      ])

      return api.post<Envelope<Company>>('/companies', {
        company: { name, roster_csv: rosterSignedId, handbook: handbookSignedId },
      })
    },
    onSuccess: (response) => onAssembled(String(response.data!.id)),
  })

  const canSubmit = name.trim() !== '' && rosterCsv != null && !assemble.isPending

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault()
        if (canSubmit) assemble.mutate()
      }}
      className="space-y-4 rounded-lg border border-border bg-card p-6"
    >
      <div>
        <label htmlFor="company-name" className="block text-[13px] font-medium">
          Company name
        </label>
        <input
          id="company-name"
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Nubo"
          className="mt-1 block w-full rounded border border-border bg-background px-2.5 py-1.5 text-[13px]"
        />
      </div>

      <div>
        <label htmlFor="roster-csv" className="block text-[13px] font-medium">
          Roster CSV
        </label>
        <input
          id="roster-csv"
          type="file"
          accept=".csv,text/csv"
          onChange={(e) => setRosterCsv(e.target.files?.[0] ?? null)}
          className="mt-1 block w-full text-[13px]"
        />
      </div>

      <div>
        <label htmlFor="handbook-pdf" className="block text-[13px] font-medium">
          Handbook PDF <span className="text-muted-foreground">(optional)</span>
        </label>
        <input
          id="handbook-pdf"
          type="file"
          accept=".pdf,application/pdf"
          onChange={(e) => setHandbook(e.target.files?.[0] ?? null)}
          className="mt-1 block w-full text-[13px]"
        />
      </div>

      <button
        type="submit"
        disabled={!canSubmit}
        className="rounded bg-primary px-3.5 py-1.5 text-[13px] font-medium text-primary-foreground shadow-btn disabled:cursor-not-allowed disabled:opacity-40"
      >
        {assemble.isPending ? 'Assembling…' : 'Assemble company'}
      </button>

      {assemble.isError && <p className="text-[13px] text-destructive">{(assemble.error as Error).message}</p>}
    </form>
  )
}
