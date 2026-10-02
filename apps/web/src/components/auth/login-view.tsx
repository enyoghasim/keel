import { useState, type FormEvent } from 'react'
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
      <form onSubmit={handleSubmit} className="w-full max-w-sm space-y-4 rounded-lg border border-border bg-card p-6">
        <div>
          <h1 className="text-[17px] font-semibold">Sign in to Keel</h1>
          {/* Mirrors Person::DEMO_PASSWORD (apps/api/app/models/person.rb) — there's no
              signup flow, so every person imported via Assemble shares this password. */}
          <p className="mt-1 text-[13px] text-muted-foreground">
            Use any imported person's email. Demo password: <code className="rounded bg-secondary px-1 py-0.5">password</code>
          </p>
        </div>

        <div>
          <label htmlFor="email" className="block text-[13px] font-medium">
            Email
          </label>
          <input
            id="email"
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="mt-1 block w-full rounded border border-border bg-background px-2.5 py-1.5 text-[13px]"
          />
        </div>

        <div>
          <label htmlFor="password" className="block text-[13px] font-medium">
            Password
          </label>
          <input
            id="password"
            type="password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="mt-1 block w-full rounded border border-border bg-background px-2.5 py-1.5 text-[13px]"
          />
        </div>

        <button
          type="submit"
          disabled={signIn.isPending}
          className="w-full rounded bg-primary px-3.5 py-1.5 text-[13px] font-medium text-primary-foreground shadow-btn disabled:cursor-not-allowed disabled:opacity-40"
        >
          {signIn.isPending ? 'Signing in…' : 'Sign in'}
        </button>

        {signIn.isError && <p className="text-[13px] text-destructive">{(signIn.error as Error).message}</p>}
      </form>
    </div>
  )
}
