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

// Mirrors McpCall#as_payload (apps/api/app/models/mcp_call.rb): one tool
// call an MCP client made with a person's token, as listed by
// Api::McpCallsController and broadcast on McpCallChannel.
export interface McpCall {
  id: number
  tool_name: string
  input: Record<string, unknown>
  output: Record<string, unknown> | null
  is_error: boolean
  latency_ms: number | null
  token_name: string | null
  created_at: string
}
