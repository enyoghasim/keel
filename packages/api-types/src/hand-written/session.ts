// Mirrors Api::SessionsController (apps/api/app/controllers/api/sessions_controller.rb).
// create/show both return the signed-in Person; destroy returns no data.
// What create/show/update return: the Person plus which command-bar
// conversation this session has open (null when none), kept server-side.
export type SessionPerson = import('./person').Person & { conversation_id?: string | null }

export interface SignInParams {
  email: string
  password: string
}
