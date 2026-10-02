import { useEffect } from 'react'
import { Link, useRouterState } from '@tanstack/react-router'
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  useSidebar,
} from '@/components/ui/sidebar'
import { KeelMark } from '../icons/keel-mark'
import { SettingsIcon } from '../icons/nav-icons'
import { navGroups } from './nav-items'

export function AppSidebar() {
  const pathname = useRouterState({ select: (state) => state.location.pathname })
  const { setOpenMobile } = useSidebar()

  // Picking a page closes the mobile drawer.
  useEffect(() => setOpenMobile(false), [pathname, setOpenMobile])

  return (
    <Sidebar>
      <SidebarHeader>
        <div className="flex items-center gap-2.5 px-2.5 pb-3 pt-1">
          <span className="flex size-6.5 shrink-0 items-center justify-center rounded bg-brand text-brand-foreground">
            <KeelMark className="size-3.75" />
          </span>
          <span className="text-[15px] font-semibold tracking-tight">Keel</span>
        </div>
      </SidebarHeader>

      <SidebarContent>
        {navGroups.map((group) => (
          <SidebarGroup key={group.label}>
            <SidebarGroupLabel>{group.label}</SidebarGroupLabel>
            <SidebarMenu>
              {group.items.map((item) => (
                <SidebarMenuItem key={item.to}>
                  <SidebarMenuButton asChild isActive={pathname === item.to || pathname.startsWith(`${item.to}/`)}>
                    <Link to={item.to}>
                      <item.icon />
                      {item.label}
                    </Link>
                  </SidebarMenuButton>
                </SidebarMenuItem>
              ))}
            </SidebarMenu>
          </SidebarGroup>
        ))}
      </SidebarContent>

      <SidebarFooter>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton asChild isActive={pathname === '/settings'}>
              <Link to="/settings">
                <SettingsIcon />
                Settings
              </Link>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarFooter>
    </Sidebar>
  )
}
