import { Building2, LogOut, Users } from 'lucide-react'
import { NavLink, Outlet } from 'react-router-dom'
import { Button } from '@/components/ui/button'
import { useIdleTimeout } from '@/hooks/useIdleTimeout'
import { useAuth } from '@/lib/auth-context'
import { cn } from '@/lib/utils'

const navItems = [
  { to: '/properties', label: 'Properties', icon: Building2 },
  { to: '/tenants', label: 'Tenants', icon: Users },
]

export function AppShell() {
  const { adminProfile, signOut } = useAuth()
  useIdleTimeout(() => void signOut())

  return (
    <div className="flex min-h-svh">
      <aside className="border-border flex w-56 shrink-0 flex-col border-r p-4">
        <div className="text-foreground mb-6 px-2 text-lg font-medium">BalajiInfra</div>
        <nav className="flex flex-1 flex-col gap-1">
          {navItems.map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                cn(
                  'flex items-center gap-2 rounded-md px-2 py-2 text-sm',
                  isActive
                    ? 'bg-accent text-accent-foreground'
                    : 'text-muted-foreground hover:bg-accent hover:text-accent-foreground',
                )
              }
            >
              <Icon className="size-4" />
              {label}
            </NavLink>
          ))}
        </nav>
        <div className="border-border space-y-2 border-t pt-4">
          {adminProfile && (
            <div className="text-muted-foreground px-2 text-xs">
              {adminProfile.name} · {adminProfile.role}
            </div>
          )}
          <Button
            variant="ghost"
            size="sm"
            className="w-full justify-start gap-2"
            onClick={() => void signOut()}
          >
            <LogOut className="size-4" />
            Sign out
          </Button>
        </div>
      </aside>
      <main className="flex-1 overflow-auto p-6">
        <Outlet />
      </main>
    </div>
  )
}
