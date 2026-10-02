import { useQueryClient } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { useState } from 'react'
import { useWorkspace, workspaceQueryKey } from '../../lib/workspace'
import { AssembleProgress } from './assemble-progress'
import { UploadForm } from './upload-form'

export function AssembleView() {
  const [companyId, setCompanyId] = useState<string | null>(null)
  const queryClient = useQueryClient()
  const company = useWorkspace().data?.data?.company

  if (companyId) {
    return <AssembleProgress companyId={companyId} />
  }

  // A reload while the job is still running: pick the progress view back up.
  if (company?.assembling) {
    return <AssembleProgress companyId={String(company.id)} />
  }

  // A deployment serves one company (the API refuses a second), so once it
  // exists this page has nothing to upload to.
  if (company) {
    return (
      <p className="rounded-lg border border-border bg-card p-6 text-[13px]">
        {company.name} is already set up. <Link to="/graph" className="font-medium underline">Open the company graph</Link>.
      </p>
    )
  }

  return (
    <UploadForm
      onAssembled={(id) => {
        setCompanyId(id)
        // The backend now has a company: let the gate and every page learn its id from there.
        void queryClient.invalidateQueries({ queryKey: workspaceQueryKey })
      }}
    />
  )
}
