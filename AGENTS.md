# Keel — Agent Guide

Keel is an AI-native operating core for a company: org chart, policies, workflows and analytics, all pointing at one company graph. Full design doc: [docs/SPEC.md](docs/SPEC.md) — read the relevant section before building a component for the first time.

This is a pnpm monorepo. Each app has its own `AGENTS.md` with stack-specific conventions — read it before touching code there.

| Folder | Stack | Docs |
| --- | --- | --- |
| [apps/api/](apps/api/) | Rails 8 API | [apps/api/AGENTS.md](apps/api/AGENTS.md) |
| [apps/web/](apps/web/) | Vite + React + TypeScript | [apps/web/AGENTS.md](apps/web/AGENTS.md) |
| [packages/schemas/](packages/schemas/) | JSON Schema contracts | [packages/schemas/AGENTS.md](packages/schemas/AGENTS.md) |
| [packages/api-types/](packages/api-types/) | Generated from `packages/schemas` | same doc |

## Three rules that are never optional

These are the architectural judgement calls the whole project rests on (SPEC.md section 2). Don't trade them away for convenience in any subproject:

1. **One company graph; nothing stores a person's name.** Policies and workflows hold a reference (`manager_of(requester)`, `role:finance_lead`, ...) resolved against the graph at the moment it's needed. If you're tempted to store a person ID where a reference belongs, stop.
2. **The AI proposes, a human approves, a deterministic engine executes.** The LLM only translates natural language into structured data and picks tools — it never decides an outcome or writes data directly. Every AI-originated write becomes a `ChangeProposal` with a computed impact report; nothing applies until a human approves it.
3. **Every AI output is traceable.** Compiled rules store the handbook quote they came from; agent runs store every tool call. If you add a new AI-touching feature, it needs a trace, not just a result.

## Testing: TDD, especially on the backend

Write the failing spec first, then the implementation. This matters most for the deterministic services (`Org::Resolver`, `Rules::Engine`, `Impact::Analyzer`, ...) — they're what let you claim "the part that makes decisions is fully tested" with a straight face (SPEC.md section 19). SPEC.md section 5 has a worked test plan for the engine; use that shape (one example per real-world case, not per method) when writing new ones.

## Commits

Small, scoped commits — not one giant commit per feature. Scope each commit to the single subproject or concern you were working in; don't stage changes across unrelated apps/packages together. A task that touches two subprojects is multiple commits, not one.
