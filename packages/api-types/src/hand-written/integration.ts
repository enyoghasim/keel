// Mirrors Api::IntegrationsController::FIELDS (apps/api/app/controllers/api/integrations_controller.rb).
// Credentials (a Slack webhook URL, Calendar OAuth tokens) are write-only —
// never present in any response this type describes.
export type IntegrationKind = 'slack' | 'google_calendar'
export type IntegrationStatus = 'disconnected' | 'connected' | 'error'

export interface Integration {
  id: number
  kind: IntegrationKind
  status: IntegrationStatus
  error_message: string | null
  created_at: string
}
