import { createRoute } from '@tanstack/react-router'
import { PageHeader } from '../components/layout/page-header'
import { PagePlaceholder } from '../components/layout/page-placeholder'
import { TokensPanel } from '../components/settings/tokens-panel'
import { getCurrentCompanyId } from '../lib/current-company'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/settings',
  component: SettingsPage,
})

function SettingsPage() {
  const companyId = getCurrentCompanyId()

  return (
    <>
      <PageHeader title="Settings" subtitle="Your account: the tokens that let outside AI tools act as you." />
      {companyId ? <TokensPanel companyId={companyId} /> : <PagePlaceholder note="No company yet — assemble one on the Assemble page first." />}
    </>
  )
}
