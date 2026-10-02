import type { ReactNode } from 'react'
import { SidebarInset, SidebarProvider } from '@/components/ui/sidebar'
import { AppSidebar } from './sidebar'
import { Topbar } from './topbar'

export function Shell({ children }: { children: ReactNode }) {
  return (
    <SidebarProvider>
      <AppSidebar />
      <SidebarInset>
        <Topbar />
        <main className="flex-1 px-4 py-5 md:px-8 md:py-7">
          <div className="mx-auto max-w-295">{children}</div>
        </main>
      </SidebarInset>
    </SidebarProvider>
  )
}
