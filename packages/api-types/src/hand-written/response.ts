// The {success, message, data, errors} envelope every Api::* controller
// renders via Renderable (apps/api/app/controllers/concerns/renderable.rb).
// `errors` is polymorphic in practice: a string array for validation
// failures, or an impact report object for ChangeProposal's "would make
// things worse" refusal — so it stays untyped here rather than guessed at.
export interface Envelope<T> {
  success: boolean
  message: string
  data?: T
  errors?: unknown
  meta?: unknown
}
