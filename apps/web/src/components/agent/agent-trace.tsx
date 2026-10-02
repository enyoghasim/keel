import { TraceDrawer } from './trace-drawer'
import { useAgentRun } from './use-agent-run'

/** The trace drawer for one live agent run. */
export function AgentTrace({ companyId, runId, onClose }: { companyId: string; runId: number; onClose: () => void }) {
  const run = useAgentRun(companyId, runId).data?.data
  return run ? <TraceDrawer run={run} onClose={onClose} /> : null
}
