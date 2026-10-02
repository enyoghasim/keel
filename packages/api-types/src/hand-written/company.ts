// Mirrors Api::CompaniesController#serialize (apps/api/app/controllers/api/companies_controller.rb).
export interface Company {
  id: number
  name: string
  locale: string
  assemble_completed_stages: string[]
  created_at: string
}

// GET /api/workspace: the one company a deployment serves, or none yet.
export interface Workspace {
  company: { id: number; name: string; assembling: boolean } | null
}
