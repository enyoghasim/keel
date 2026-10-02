import { createRoute } from '@tanstack/react-router'
import { PageHeader } from '../components/layout/page-header'
import { PagePlaceholder } from '../components/layout/page-placeholder'
import { McpCallsPanel } from '../components/settings/mcp-calls-panel'
import { TokensPanel } from '../components/settings/tokens-panel'
import { useCurrentPerson } from '../lib/auth'
import { useCompanyId } from '../lib/workspace'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/settings',
  component: SettingsPage,
})

function SettingsPage() {
  const companyId = useCompanyId()
  const personId = useCurrentPerson(companyId).data?.data?.id

  return (
    <>
      <PageHeader title="Settings" subtitle="Your account: the tokens that let outside AI tools act as you, and what they have asked Keel." />
      {companyId ? (
        <div className="space-y-4">
          <TokensPanel companyId={companyId} />
          {personId !== undefined && <McpCallsPanel companyId={companyId} personId={personId} />}
        </div>
      ) : (
        <PagePlaceholder note="No company yet — assemble one on the Assemble page first." />
      )}
    </>
  )
}
