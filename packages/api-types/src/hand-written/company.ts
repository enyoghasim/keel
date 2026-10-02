// Mirrors Api::CompaniesController#serialize (apps/api/app/controllers/api/companies_controller.rb).
export interface Company {
  id: number
  name: string
  locale: string
  assemble_completed_stages: string[]
  created_at: string
}
