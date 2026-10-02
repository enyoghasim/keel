import { useState } from 'react'
import { setCurrentCompanyId } from '../../lib/current-company'
import { AssembleProgress } from './assemble-progress'
import { UploadForm } from './upload-form'

export function AssembleView() {
  const [companyId, setCompanyId] = useState<string | null>(null)

  if (companyId) {
    return <AssembleProgress companyId={companyId} />
  }

  return (
    <UploadForm
      onAssembled={(id) => {
        setCurrentCompanyId(id)
        setCompanyId(id)
      }}
    />
  )
}
