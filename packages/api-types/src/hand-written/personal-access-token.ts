// Mirrors PersonalAccessToken::FIELDS (apps/api/app/models/personal_access_token.rb),
// what Api::PersonalAccessTokensController renders. `token` — the raw bearer
// value for the MCP endpoint — is in the create response only.
export interface PersonalAccessToken {
  id: number
  name: string
  last_used_at: string | null
  revoked_at: string | null
  created_at: string
}

export interface CreatedPersonalAccessToken extends PersonalAccessToken {
  token: string
}
