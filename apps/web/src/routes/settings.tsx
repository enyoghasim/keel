import { createRoute } from '@tanstack/react-router'
import { PageHeader } from '../components/layout/page-header'
import { PagePlaceholder } from '../components/layout/page-placeholder'
import { CalendarPanel } from '../components/settings/calendar-panel'
import { DemoResetPanel } from '../components/settings/demo-reset-panel'
import { McpCallsPanel } from '../components/settings/mcp-calls-panel'
import { SlackPanel } from '../components/settings/slack-panel'
import { TokensPanel } from '../components/settings/tokens-panel'
import { useCurrentPerson } from '../lib/auth'
import { useCompanyId, useWorkspace } from '../lib/workspace'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/settings',
  component: SettingsPage,
})

function SettingsPage() {
  const companyId = useCompanyId()
  const person = useCurrentPerson(companyId).data?.data
  const personId = person?.id
  const isHrAdmin = person?.roles.includes('hr_admin') === true
  // Only where the deployment turned DEMO_RESET on, and only for someone who may use it.
  const canResetDemo = useWorkspace().data?.data?.demo_reset === true && isHrAdmin

  return (
    <>
      <PageHeader title="Settings" subtitle="Your account: the tokens that let outside AI tools act as you, and what they have asked Keel." />
      {companyId ? (
        <div className="space-y-4">
          <TokensPanel companyId={companyId} />
          {personId !== undefined && <McpCallsPanel companyId={companyId} personId={personId} />}
          {isHrAdmin && <SlackPanel companyId={companyId} />}
          {isHrAdmin && <CalendarPanel companyId={companyId} />}
          {canResetDemo && <DemoResetPanel companyId={companyId} />}
        </div>
      ) : (
        <PagePlaceholder note="No company yet — assemble one on the Assemble page first." />
      )}
    </>
  )
}
