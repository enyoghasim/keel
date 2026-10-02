// Mirrors AgentRun#as_payload and AgentStep#as_payload
// (apps/api/app/models/agent_run.rb, agent_step.rb) — what
// Api::AgentRunsController renders and AgentChannel broadcasts.
export type AgentRunStatus = 'pending' | 'running' | 'completed' | 'failed'

// kind "llm": a model reply; output holds its text and any tool calls it
// asked for. kind "tool": one tool call; input is the arguments the model
// passed, output is what the tool returned.
export interface AgentStep {
  id: number
  position: number
  kind: 'llm' | 'tool'
  tool_name: string | null
  input: Record<string, unknown> | null
  output: Record<string, unknown> | null
  latency_ms: number | null
  tokens: number | null
}

export interface AgentRun {
  id: number
  person_id: number
  message: string
  status: AgentRunStatus
  final_text: string | null
  total_tokens: number
  error_message: string | null
  created_at: string
  steps: AgentStep[]
}

export type AgentChannelEvent = { event: 'run'; run: AgentRun } | { event: 'step'; step: AgentStep }
