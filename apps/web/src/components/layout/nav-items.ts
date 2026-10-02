import {
  AssembleIcon,
  GraphIcon,
  InboxIcon,
  InsightsIcon,
  PoliciesIcon,
  ProposalsIcon,
  TrustIcon,
  WorkflowsIcon,
} from '../icons/nav-icons'

export const navGroups = [
  {
    label: 'Workspace',
    items: [
      { to: '/assemble', label: 'Assemble', icon: AssembleIcon },
      { to: '/graph', label: 'Graph', icon: GraphIcon },
      { to: '/policies', label: 'Policies', icon: PoliciesIcon },
      { to: '/workflows', label: 'Workflows', icon: WorkflowsIcon },
      { to: '/proposals', label: 'Proposals', icon: ProposalsIcon },
      { to: '/inbox', label: 'Inbox', icon: InboxIcon },
    ],
  },
  {
    label: 'Measure',
    items: [
      { to: '/insights', label: 'Insights', icon: InsightsIcon },
      { to: '/trust', label: 'Trust', icon: TrustIcon },
    ],
  },
] as const
