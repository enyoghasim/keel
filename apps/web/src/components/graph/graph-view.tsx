import { useQuery } from '@tanstack/react-query'
import type { Department, Envelope, Person } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'
import { PagePlaceholder } from '../layout/page-placeholder'
import { OrgCanvas } from '../org-canvas/org-canvas'
import { PersonPanel } from './person-panel'

export function GraphView({ companyId }: { companyId: string }) {
  const [selectedPersonId, setSelectedPersonId] = useState<number | null>(null)
  const [colorByDepartment, setColorByDepartment] = useState(true)

  const peopleQuery = useQuery({
    queryKey: ['people', companyId],
    queryFn: () => api.get<Envelope<Person[]>>(`/companies/${companyId}/people`),
  })
  const departmentsQuery = useQuery({
    queryKey: ['departments', companyId],
    queryFn: () => api.get<Envelope<Department[]>>(`/companies/${companyId}/departments`),
  })

  if (peopleQuery.isPending || departmentsQuery.isPending) {
    return <PagePlaceholder note="Loading the org chart…" />
  }
  if (peopleQuery.isError || departmentsQuery.isError) {
    const error = (peopleQuery.error ?? departmentsQuery.error) as Error
    return <PagePlaceholder note={`Couldn't load the org chart: ${error.message}`} />
  }

  const people = peopleQuery.data?.data ?? []
  const departments = departmentsQuery.data?.data ?? []

  if (people.length === 0) {
    return <PagePlaceholder note="No people yet. Assemble a company to build the org chart." />
  }

  const selectedPerson = people.find((p) => p.id === selectedPersonId) ?? null
  const selectedDepartment =
    selectedPerson?.department_id != null
      ? (departments.find((d) => d.id === selectedPerson.department_id) ?? null)
      : null
  const selectedManager =
    selectedPerson?.manager_id != null ? (people.find((p) => p.id === selectedPerson.manager_id) ?? null) : null

  return (
    <div className="flex items-start gap-4">
      <div className="min-w-0 flex-1 space-y-3">
        <label className="flex w-fit items-center gap-2 text-[13px] font-medium">
          <input
            type="checkbox"
            checked={colorByDepartment}
            onChange={(e) => setColorByDepartment(e.target.checked)}
          />
          Colour by department
        </label>
        <OrgCanvas
          people={people}
          departments={departments}
          colorByDepartment={colorByDepartment}
          selectedPersonId={selectedPersonId}
          onSelectPerson={setSelectedPersonId}
        />
      </div>
      <PersonPanel person={selectedPerson} department={selectedDepartment} manager={selectedManager} />
    </div>
  )
}
