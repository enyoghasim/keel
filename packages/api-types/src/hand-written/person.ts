// Mirrors Api::PeopleController::FIELDS (apps/api/app/controllers/api/people_controller.rb).
export interface Person {
  id: number
  name: string
  email: string
  title: string | null
  department_id: number | null
  manager_id: number | null
  location: string | null
  start_date: string | null
  roles: string[]
}
