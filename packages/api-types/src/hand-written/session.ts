// Mirrors Api::SessionsController (apps/api/app/controllers/api/sessions_controller.rb).
// create/show both return the signed-in Person; destroy returns no data.
export interface SignInParams {
  email: string
  password: string
}
