import { useState, type FormEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useSignIn } from '../../lib/auth'

export function LoginView({ companyId }: { companyId: string }) {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const signIn = useSignIn(companyId)

  function handleSubmit(e: FormEvent) {
    e.preventDefault()
    signIn.mutate({ email, password })
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <Card className="w-full max-w-sm p-6">
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <h1 className="text-[17px] font-semibold">Sign in to Keel</h1>
          {/* Mirrors Person::DEMO_PASSWORD (apps/api/app/models/person.rb) — there's no
              signup flow, so every person imported via Assemble shares this password. */}
          <p className="mt-1 text-[13px] text-muted-foreground">
            Use any imported person's email. Demo password: <code className="rounded bg-secondary px-1 py-0.5">password</code>
          </p>
        </div>

        <div>
          <Label htmlFor="email">Email</Label>
          <Input id="email" type="email" required value={email} onChange={(e) => setEmail(e.target.value)} className="mt-1.5" />
        </div>

        <div>
          <Label htmlFor="password">Password</Label>
          <Input id="password" type="password" required value={password} onChange={(e) => setPassword(e.target.value)} className="mt-1.5" />
        </div>

        <Button type="submit" disabled={signIn.isPending} className="w-full">
          {signIn.isPending ? 'Signing in…' : 'Sign in'}
        </Button>

        {signIn.isError && <p className="text-[13px] text-destructive">{(signIn.error as Error).message}</p>}
      </form>
      </Card>
    </div>
  )
}
