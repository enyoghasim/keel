# Keel

**An AI-native operating core for a company: org chart, policies, workflows and analytics, all pointing at one company graph.**

Keel reads the documents a company already has (a messy employee spreadsheet and a handbook PDF), builds a single model of the company, and keeps every rule and workflow connected to it. When something changes, Keel shows exactly what will break *before* it happens and lets a human approve the change.

```bash
docker compose up --build      # then open http://localhost:8080
```

Sign in as `demo.hr@factorial.co` with password `password` (Head of People, an HR admin).

- [About the project](#about-the-project)
- [Run it (Docker)](#run-it-docker)
- [Deployment](#deployment)
- [Local development](#local-development)
- [Repository layout](#repository-layout)

---

## About the project

### The problem

Every small or mid-sized company runs on four things: who reports to whom, the rules everyone must follow, the processes that move work along, and the questions leaders ask about all of it. Today these are configured by hand. An HR manager spends days clicking through settings screens to set up approval chains, the handbook sits in a PDF nobody reads, and the moment someone is promoted or a team moves, half the approval chains silently break.

Say a 70-person logistics company promotes Ada to Head of Operations and moves Sales under her. In most HR tools, every workflow that named the old Sales manager still routes to him. Nobody notices until an expense sits unapproved for two weeks.

### What it does

| Area | What you get |
| --- | --- |
| **Assemble** (`/assemble`) | Upload a roster CSV and a handbook PDF. An LLM maps the messy columns, the org chart builds itself live on screen, and policies are extracted as rules, each stored with the exact handbook sentence it came from. Anything vague is flagged as an ambiguity for a human to resolve; a rule whose quote isn't verbatim in the handbook is dropped. |
| **Graph** (`/graph`) | The company graph: people, departments, managers and roles. |
| **Policies** (`/policies`) | Rules with their source quotes, ambiguities to resolve, a scenario tester ("Engineering, conference ticket, €950" → auto-approved, rule highlighted), conflict detection between rules, and versioned publishing. |
| **Workflows** (`/workflows`, `/inbox`) | Approval flows that reference roles, not people, resolved at the moment each step becomes active. Steps are directly editable — add, reorder, remove, configure a task or notify step — not just AI-drafted from a plain-English instruction: a draft workflow saves immediately, and an edit to a live one goes through the same change-proposal review either way. A dry-run test mode, and an inbox where approvers approve, reject or override (with a reason). |
| **Agent** (`⌘K`) | Ask "Can I expense a €1,200 client dinner?" or "Move Sales under Ada". The agent calls tools; the deterministic engine decides. Every step is traced. |
| **Proposals** (`/proposals`) | Every AI-originated write becomes a change proposal with a computed impact report (chains rerouted, chains broken, approval-load changes) and a plain-English explanation. Nothing applies until a human approves it. |
| **Insights** (`/insights`) | Natural-language analytics. The question becomes a typed query object, shown to the user; the query is run by a deterministic builder, never generated SQL. |
| **Trust** (`/trust`) | The eval harness: three suites, behavioural scoring, compile stability, LLM-as-judge checked against hand labels, versioned prompts with a side-by-side comparison, and a queue that turns real human corrections into new test cases. |
| **Integrations** (Settings) | Connect Slack (an incoming webhook — no account needed) and Google Calendar (OAuth2) so a workflow step bound to one fires a real message or creates a real event, instead of only logging that someone should have been told. |
| **MCP server** (`/mcp`) | A subset of Keel's tools exposed over the Model Context Protocol, so Claude Desktop and other MCP clients can ask Keel who approves their leave. Authenticated with personal access tokens from Settings. |

### Three design rules

These are the architectural judgement calls the whole project rests on (full reasoning in [docs/SPEC.md](docs/SPEC.md), section 2).

1. **One company graph; nothing stores a person's name.** Policies and workflows hold a *reference* (`manager_of(requester)`, `role:finance_lead`) that is resolved against the graph when it's needed. When the finance lead changes, nothing needs editing. This is also what makes impact analysis possible: resolve every reference against a copy of the graph with the change applied and diff the results.
2. **The AI proposes, a human approves, a deterministic engine executes.** The LLM only translates natural language into structured data and picks tools. It never decides whether a request is approved and never writes data directly. Decisions come from `Rules::Engine`, a plain Ruby class: the same request against the same policy version always gives the same answer. That makes decisions auditable, makes errors separable (a bad compile is an AI problem you can measure; a wrong outcome from good rules is an ordinary bug), and keeps the runtime fast and cheap, because the LLM runs when a policy changes, not on every request.
3. **Every AI output is traceable.** Compiled rules store their handbook quote, agent runs store every model call and tool call with input, output, latency and cost, and every prompt is versioned and scored against the same test set.

### Architecture

```
 Browser ──► nginx (one port) ──┬─► React app (static files)
                                ├─► /api, /cable, /mcp, /rails/active_storage ──► Rails 8 API
                                                                                    │
                                              ┌─────────────────────────────────────┤
                                              ▼                                     ▼
                                  Deterministic services                      AI services (ruby_llm)
                                  Org::Resolver, Rules::Engine,               Assemble::*, Agent::Runner,
                                  Workflows::Runtime, Impact::*,              Insights::Interpreter,
                                  Insights::QueryBuilder                      Evals::Judge
                                              │                                     │
                                              └──────── PostgreSQL 16 + pgvector ───┘
```

- **`apps/api`: Rails 8 API.** `app/services/` is split on purpose. The *deterministic* family (`org/`, `rules/`, `workflows/`, `impact/`, `insights/query_builder.rb`) makes every decision and is unit-tested exhaustively. The *AI* family (`assemble/`, `agent/`, `evals/`, `insights/interpreter.rb`) calls the model, validates the output against a JSON Schema, then hands structured data to the deterministic side. An AI service never decides an outcome.
- **`apps/web`: Vite + React + TypeScript.** TanStack Router and Query, Tailwind v4, React Flow for the org chart and workflow graphs, live updates over Action Cable (assemble progress, agent trace, eval progress).
- **`packages/schemas`**: JSON Schema contracts for every LLM output. Rails validates against them at runtime; `packages/api-types` generates TypeScript types from the same files.
- **Background work** runs on Solid Queue (inside the web process by default); Action Cable and cache use Solid Cable and Solid Cache. Everything lives in the one PostgreSQL database server, so there is no Redis.
- **One implementation, two front doors.** The MCP tools are thin adapters over the same Ruby tool classes the in-app agent uses.

### How AI quality is evaluated

"Evaluating AI in production is the hard part", so the Trust page is not optional.

- **Three suites**: `policy_extraction` (a handbook passage → the rules it should produce), `agent` (a message and an acting person → the tools called and the outcome), `insights` (a question → the expected query object). Cases live in [`fixtures/evals/`](fixtures/evals/) and load with `bin/rails evals:load`.
- **Behaviour, not text.** Comparing compiled JSON to expected JSON is too strict, since two rule sets can behave identically. Keel generates probe requests and runs both the expected and the compiled rules through `Rules::Engine`; the score is the share of probes where decisions and approvers match. A `lt` where `lte` was meant fails exactly one probe, and the failure diff shows which.
- **Compile stability.** Each passage can be compiled several times at production temperature and the outputs compared pairwise by behaviour: a single number for "how consistent is this?".
- **LLM-as-judge, with a check on the judge.** Agent answers are graded 1–5 on correctness, citation, clarity and not claiming actions that didn't happen. Five cases carry hand-written labels, and the page shows how closely the judge agrees with them.
- **Versioned prompts.** Run a suite against any prompt version, compare two runs side by side (which cases flipped), and promote a challenger. Promotion warns if it regresses a case the current version passes.
- **A feedback loop.** An approver overriding the engine, a thumbs-down on an agent answer and a rejected proposal each create a *candidate* eval case, to be reviewed and added to the suite.

The suites need a model key to run (see [Configuration](#configuration)); no scores are quoted here because they depend on the model and your data. Run them on `/trust` to get your own.

### Known limitations

- **Single company per deployment.** There is no multi-tenancy; the API refuses a second company.
- **Demo-grade authentication.** There is no signup flow: every imported person shares one demo password (`Person::DEMO_PASSWORD`). Replace this before exposing Keel to real users. MCP uses personal access tokens, not OAuth.
- **The AI features need an OpenAI key** (the default model is `gpt-5.1`). Without one the whole deterministic core still works, and the AI features say plainly that no model key is configured instead of failing obscurely.
- **English handbooks only.**
- **Org chart readability.** The graph stacks reports who lead no one in a column under their manager and wraps wide rows, but all 78 people in one fit-to-screen view are still small; zoom and pan to read names.

---

## Run it (Docker)

You need Docker with the Compose plugin. Nothing else.

```bash
git clone <this repo> keel && cd keel
docker compose up --build
```

Then open **http://localhost:8080**.

The first start takes a few minutes: it builds two images, creates the databases, and loads the demo company. Later starts take seconds. `docker compose up` is done when the `web` service logs that nginx is ready.

| What | Where |
| --- | --- |
| The app (React UI, API, WebSocket and MCP, all behind one port) | **http://localhost:8080** |
| Demo sign-in | `demo.hr@factorial.co` / `password` (HR admin) |
| An employee, to try the agent as | `catarina.rodrigues@factorial.co` / `password` (Sales; her manager is `carlos.martinez@factorial.co`) |
| Change the port | `KEEL_PORT=3000 docker compose up` or set it in `.env` |

PostgreSQL and the Rails server are not published on the host: only the web port is. Containers: `db` (Postgres 16 with pgvector), `api` (Rails, with background jobs in the same process), `web` (nginx serving the built React app and proxying to `api`).

On a blank database the first start loads **Demo Factorial**, a 28-person demo company with a handbook, rules, workflows and three months of request history. To start empty and assemble your own company from a CSV and a PDF on `/assemble`, set `SEED_DEMO=false` before the first `up` (or wipe the data with `docker compose down -v`).

Handy commands:

```bash
docker compose logs -f api            # watch the Rails server and jobs
docker compose down                   # stop; data is kept in volumes
docker compose down -v                # stop and delete all data (database + uploads)
docker compose exec api bin/rails evals:load   # load the eval fixtures into the Trust page
```

### A public URL, for remote testing

`docker compose up` also starts a `tunnel` service: a free [Tunnelmole](https://tunnelmole.com) tunnel in front of `web`, printing a public `https://*.tunnelmole.net` URL you can hand to an MCP client that isn't on your machine, or open from a phone. `db`, `api` and `web` stay quiet in the foreground on purpose (Compose's `attach: false`) so that URL — and each service's own Created/Started/Healthy line — isn't buried in request logs; nothing is lost, `docker compose logs api` (or `web`, `db`) still has everything.

Don't want a public URL for this run? `docker compose up api web` (lists the services explicitly, leaving out `tunnel`).

### Configuration

Everything has a default, so a plain `docker compose up` works. To change anything, copy [`.env.example`](.env.example) to `.env` (Compose reads it automatically).

| Variable | Default | Purpose |
| --- | --- | --- |
| `KEEL_PORT` | `8080` | The one port Keel is served on. |
| `OPENAI_API_KEY` | none | Turns on the AI features: Assemble, the `⌘K` agent, Insights, evals. |
| `ANTHROPIC_API_KEY` | none | Optional, for Anthropic models via ruby_llm. |
| `SEED_DEMO` | `true` | Load the Demo Factorial demo company on a blank database. |
| `DEMO_RESET` | `false` | For a public demo: show **Reset demo** on Settings (to an hr_admin), which wipes the deployment and reloads Demo Factorial. Destructive, so off by default. |
| `DATABASE_PASSWORD` | `postgres` | Postgres password. Change it if anything else can reach the database. |
| `SECRET_KEY_BASE` | a local-only placeholder | Rails signs sessions with it. Set your own (`openssl rand -hex 64`) for any deployment others can reach. |
| `AR_ENCRYPTION_PRIMARY_KEY`, `AR_ENCRYPTION_DETERMINISTIC_KEY`, `AR_ENCRYPTION_KEY_DERIVATION_SALT` | local-only placeholders | Encrypt stored integration credentials (the Slack webhook URL, Calendar OAuth tokens) at rest. Generate your own (`bin/rails db:encryption:init`) for any deployment others can reach. |
| `GOOGLE_CALENDAR_CLIENT_ID`, `GOOGLE_CALENDAR_CLIENT_SECRET`, `GOOGLE_CALENDAR_REDIRECT_URI` | none | Connects Settings > Integrations to Google Calendar — see [`.env.example`](.env.example) for how to create the OAuth client. Slack needs no env setup; it's connected from inside the app. |

With an OpenAI key set, handbook chunks of the demo company are embedded on start so the agent's handbook search uses vector search; to embed after adding a key later, run `docker compose exec api bin/rails handbook:embed`.

### Connecting an MCP client

On **Settings**, create a personal access token. Keel's MCP endpoint is `http://localhost:8080/mcp`; point an MCP client at it with the token as a bearer token. Every call is recorded and listed on the Settings page. For a client that isn't on your machine, use the public URL `docker compose up` already printed (see [above](#a-public-url-for-remote-testing)) in place of `localhost:8080`.

---

## Deployment

Keel is the same three containers in production as it is on your laptop. The `docker-compose.yml` in the repository root is a working production layout; what changes is the hardening around it.

### What to run

| Service | Image | Notes |
| --- | --- | --- |
| `db` | `pgvector/pgvector:pg16` | Any PostgreSQL 16 with the `vector` extension works. Rails creates four databases on it (`keel_production`, plus `_cache`, `_queue`, `_cable`). |
| `api` | built from `apps/api/Dockerfile` | Rails behind Thruster. The entrypoint runs `db:prepare` on every start, so schema migrations apply automatically, and seeds the demo company when `SEED_DEMO` isn't `false`. |
| `web` | built from `apps/web/Dockerfile` | nginx: static React build, and a reverse proxy for `/api`, `/cable` (WebSocket), `/mcp` and `/rails/active_storage`. |

Both Dockerfiles use the **repository root as the build context** (the API needs `packages/schemas` at boot):

```bash
docker build -f apps/api/Dockerfile -t keel-api .
docker build -f apps/web/Dockerfile -t keel-web .
```

### Deploying to a Docker host (Coolify, Dokploy, plain Compose)

1. **Point your platform at `docker-compose.yml`**, or run `docker compose up -d --build` on the server.
2. **Set the environment** (`.env` or the platform's variables): `SECRET_KEY_BASE` (new random value), `DATABASE_PASSWORD`, `OPENAI_API_KEY`, and `KEEL_PORT` if 8080 is taken.
3. **Put TLS in front of the `web` port.** Keel speaks plain HTTP on that port; terminate HTTPS at your platform's proxy (Coolify and Dokploy do this for you) and forward to it. Forward the original `Host` header unchanged: Action Cable checks the browser's `Origin` against it and will refuse the live connection (assemble progress, agent trace) if they disagree.
4. **Persist the volumes.** `keel_db` holds all data and `keel_storage` holds uploaded rosters and handbooks. Back up `keel_db` (for example with `pg_dump`).
5. **Decide about demo data.** Leave `SEED_DEMO=true` for a public demo (visitors can sign in straight away), or set it to `false` for a real company and assemble it from your own files. Seeding only ever runs against an empty database, and a deployment serves one company.

### Before you expose it to the internet

- **Replace the shared demo password.** Every person imported by Assemble or seeded gets `password`. There is no signup flow, so for anything beyond a demo, set real passwords on the `people` records or put Keel behind your own authentication.
- **Set a spending cap on the model provider.** Agent, Assemble and eval runs call a paid API. Keel limits one agent run at a time per person and 30 per hour, plus 60 agent runs and 10 Assemble attempts per IP address per hour, but the provider cap is the real backstop.
- **Don't publish PostgreSQL.** The provided Compose file keeps it on the internal network; keep it that way.
- **Use your own `SECRET_KEY_BASE`.** The placeholder in `docker-compose.yml` is public.

### How the pieces find each other

The browser never stores which company it is looking at. On load the app asks the backend (`GET /api/workspace`) which company this deployment serves: if there is none yet it goes to **Assemble**, otherwise to the **sign-in** page and then the company graph. Sessions are server-side, in a signed `httponly` cookie, and the backend also remembers which agent conversation each session has open, so a refresh brings the thread back.

---

## Local development

For working on the code you'll want the services running natively. You need Ruby 4.0 (see `apps/api/.ruby-version`), Node 22 with pnpm 10 (`corepack enable`), and PostgreSQL 16 with pgvector.

```bash
pnpm install
pnpm gen:types                   # generate TypeScript types from packages/schemas

cd apps/api
cp .env.example .env             # database host and, optionally, model keys
bundle install
bin/rails db:prepare
bin/rails db:seed                # the Demo Factorial demo company
bin/rails evals:load             # eval fixtures for the Trust page
cd ../..

pnpm dev                         # Rails on :3000 and Vite on :5173, proxied together
```

Open http://localhost:5173. Run `pnpm gen:types` again whenever a schema in `packages/schemas` changes: the generated types are not committed.

### Tests and linting

```bash
pnpm --filter api test           # RSpec (the deterministic services are the core of this)
pnpm --filter web test           # Vitest + Testing Library
pnpm lint                        # rubocop, then oxlint
cd apps/web && npx tsc -b        # typecheck
```

Backend work is test-first, especially for the deterministic services (`Org::Resolver`, `Rules::Engine`, `Impact::Analyzer`, ...): one example per real-world case, not one per method. The model itself is stubbed in specs, so the suite needs no API key.

---

## Repository layout

| Path | What's in it |
| --- | --- |
| [`apps/api/`](apps/api/) | Rails 8 API, with its own [agent guide](apps/api/AGENTS.md). |
| [`apps/web/`](apps/web/) | Vite + React + TypeScript app, with its own [agent guide](apps/web/AGENTS.md). |
| [`packages/schemas/`](packages/schemas/) | JSON Schema contracts for every LLM output. |
| [`packages/api-types/`](packages/api-types/) | TypeScript types: generated from the schemas, plus hand-written API shapes. |
| [`fixtures/evals/`](fixtures/evals/) | Hand-written eval cases for the three suites. |
| [`docs/SPEC.md`](docs/SPEC.md) | The full design document. |
| [`docs/decisions/`](docs/decisions/) | Architecture decision records: why the LLM compiles rules and an engine executes them, and five more. |
| [`docker-compose.yml`](docker-compose.yml) | The one-command setup. |
