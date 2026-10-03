# Keel — Technical Specification & Build Plan

Oct 2, 2026 · @David

## 1. Overview

Keel is an AI-native operating core for a company: it turns a messy employee spreadsheet and a handbook PDF into a living org chart, executable policies, and workflows that an agent can run and a human can trust. It is built in one weekend as a portfolio piece for Factorial's founding AI Software Developer role.

### The problem

Every small or mid-sized company runs on four things: who reports to whom (the org chart), the rules everyone must follow (policies), the processes that move work along (workflows), and the questions leaders ask about all of it (analytics). Today these are configured by hand. An HR manager spends days clicking through settings screens to set up approval chains, the handbook sits in a PDF nobody reads, and the moment someone is promoted or a team moves, half the approval chains silently break.

For example, a 70-person logistics company promotes Ada to Head of Operations and moves Sales under her. In most HR tools today, every workflow that named the old Sales manager still routes to him. Nobody notices until an expense sits unapproved for two weeks.

### What Keel does

Keel lets a company describe how it works instead of configuring it. It reads the documents the company already has, builds a single model of the company, and keeps every rule and workflow connected to that model. When something changes, Keel shows exactly what will break before it happens and lets a human approve the change.

### The demo story (3 minutes)

1. Upload a messy CSV and a handbook PDF. The org chart and policies assemble themselves live on screen.
2. Click any rule to see the exact handbook sentence it came from. Resolve an ambiguity Keel flagged.
3. Type "Move Sales under Ada" in the command bar. Keel shows an impact preview: 14 chains reroute, 1 breaks. Fix it and approve.
4. Ask "Who is overloaded with approvals?" and get a chart.
5. Open the Trust page and show prompt v2 beating v1 on the test set.
6. In Claude Desktop, ask "Who approves my leave?" and watch it answer by calling Keel over MCP.

### What the recruiter should conclude

| JD requirement | Where Keel proves it |
| --- | --- |
| Workflows, org charts, policies, analytics | All four are first-class components, connected by one company graph |
| Agentic workflows and LLM architecture opinions | Agent with tools; the "AI proposes, engine executes" design |
| Evaluating AI in production is the hard part | Trust page: test set, stability scores, prompt comparison, override feedback loop |
| Reliability and user friction before model complexity | Ambiguity detection, impact previews, human approval, deterministic runtime |
| Breaking down non-deterministic outputs | Compile stability metric and per-case failure diffs |
| Ruby on Rails and React | Rails 8 API and React + TypeScript web app in a pnpm monorepo |
| Explaining decisions to non-engineers | Plain-English impact reports and README decision records |
| Fits where Factorial is heading | MCP server, matching Factorial One and the YepCode acquisition |

## 2. Design principles

Three rules shape every component. They are the most important part of the project, because they show architectural judgement rather than API-calling. Put them at the top of the README.

### Principle 1: One company graph, and everything points to roles, not names

There is exactly one source of truth: the company graph of people, departments, managers and roles. Policies and workflows never store a person's name. They store a **reference** that is resolved against the graph at the moment it is needed.

For example, the expense workflow does not say "send to Chidi Okafor". It says `manager_of(requester)`, then `role:finance_lead`. When Chidi leaves and Amaka becomes the finance lead, nothing needs editing. The next request resolves to Amaka automatically.

This is why reorgs are safe in Keel and painful in most tools. It also makes impact analysis possible: to know what a reorg will do, Keel simply resolves every reference against a copy of the graph with the change applied and compares the results.

Supported references:

| Reference | Resolves to | Example |
| --- | --- | --- |
| `requester` | The person making the request | Ngozi |
| `manager_of(requester)` | Their direct manager | Ngozi's manager, Tunde |
| `skip_manager_of(requester)` | Manager's manager | Tunde's manager, Ada |
| `head_of(requester.department)` | Department head | Head of Sales |
| `role:finance_lead` | Whoever holds that role company-wide | Amaka |
| `role:it_admin` | Whoever holds that role | Emeka |

### Principle 2: The AI proposes, a human approves, a deterministic engine executes

The LLM is allowed to do two things: translate natural language into structured data, and choose which tool to call. It is never allowed to change data directly or decide whether a request is approved.

Every write the AI wants to make becomes a **Change Proposal**. A proposal holds a diff and a computed impact report, and nothing happens until a human approves it. Every decision about a request (approve, reject, which approvers) is made by `Rules::Engine`, a plain Ruby class with full test coverage. The same request against the same policy version always gives the same answer.

This matters for three reasons. First, decisions become auditable, which Factorial cares about because of the EU AI Act and its stated commitment to human oversight. Second, errors become separable: a wrong outcome is either a bad compile (an AI problem you can measure) or an engine bug (a normal bug you can test). Third, the runtime is fast and cheap, because the LLM runs once when a policy changes, not on every request.

### Principle 3: Every AI output is traceable

Nothing the AI produces is a black box. Each compiled rule stores the exact handbook quote it came from. Each agent answer stores every tool call, input, output, latency and token cost. Each prompt is versioned, and every version is scored against the same test set.

In practice this means a user can hover a rule and see its source sentence highlighted, an engineer can open any agent run and replay it step by step, and the team can say "prompt v2 is 11 points more accurate than v1" with evidence.

## 3. System architecture

Keel is a pnpm monorepo with two apps: a Rails 8 API that runs AI and analysis work in Solid Queue jobs and streams progress over Action Cable, and a React + TypeScript single-page app. A shared schema package keeps the contracts between them in one place, so Ruby and TypeScript never disagree about what a rule or workflow looks like.

&#91;embedded content: Keel architecture · AI services hand validated JSON to deterministic services\]

Requests enter through the browser or MCP; anything that needs a model runs in a job, and every decision is made on the highlighted deterministic side.

### Stack

| Layer | Choice | Why this, not something else |
| --- | --- | --- |
| Repo | pnpm workspaces monorepo (`apps/api`, `apps/web`, `packages/schemas`, `packages/api-types`) | One repo, one `pnpm dev` starts everything; contracts shared between Ruby and TypeScript |
| Backend | Rails 8 in API mode (`apps/api`) | Factorial's stack; JSON endpoints plus Action Cable |
| Frontend | React 18 + TypeScript + Vite SPA (`apps/web`) | Independent frontend, fast dev server, deploys as static files |
| Routing and data | TanStack Router + TanStack Query | Typed routes; caching, refetching and mutations without hand-written state |
| UI | Tailwind + shadcn/ui, React Flow, Recharts, cmdk | Production-looking UI quickly; graphs and charts out of the box |
| Shared contracts | `packages/schemas` (JSON Schema files) → `json-schema-to-typescript` → `packages/api-types` | The same schemas validate LLM output in Ruby and type the frontend |
| Database | PostgreSQL 16 + `jsonb` + pgvector (`neighbor` gem) | Rules and workflows are JSON documents; handbook chunks are searchable by meaning |
| Background jobs | Solid Queue (Rails 8 default) | No Redis needed; runs assemble, evals, impact analysis |
| Real-time | Action Cable (Solid Cable) | Streams assembly progress, agent traces, eval progress |
| LLM client | `ruby_llm` gem | One API for chat, tool calling, structured output and embeddings across providers |
| PDF | `pdf-reader` gem | Extracts handbook text page by page |
| Validation | `json_schemer` gem | Every LLM output is validated against a JSON Schema before it is saved |
| MCP | `mcp` gem (official Ruby SDK) | Exposes Keel's tools to external agents like Claude Desktop |
| Tests | RSpec + FactoryBot (API), Vitest (web) | Engine and resolver at full coverage |
| Deploy | API as a Docker service, web as a static build, both on Coolify or Dokploy | You already run these; live public URL |

### The four layers

**Presentation (React SPA in `apps/web`).** Routes are defined with TanStack Router, and each route loads its data through TanStack Query hooks that call one typed API client. Pages subscribe to Action Cable channels for live updates.

**Application (controllers + jobs).** Controllers are thin: they validate input, enqueue a job or call a service, and render. Anything that touches an LLM runs in a job, so web requests never wait on a model.

**Domain services (plain Ruby in `app/services`).** This is where the logic lives. Services are split into two families. *Deterministic services* (`Org::Resolver`, `Rules::Engine`, `Workflows::Runtime`, `Impact::Analyzer`, `Insights::QueryBuilder`) have no LLM calls and are fully unit-tested. *AI services* (`Assemble::*`, `Agent::Runner`, `Evals::Judge`) call the LLM, validate the output against a schema, and hand structured data to the deterministic side.

**Data (PostgreSQL).** Relational tables for people and requests; `jsonb` columns for rules, workflow steps, diffs and traces; a vector column for handbook chunks.

### Monorepo structure

```
keel/
  pnpm-workspace.yaml        packages: apps/*, packages/*
  package.json               scripts: dev (both apps in parallel), build, test, gen:types
  apps/
    api/                     Rails 8 API; package.json scripts wrap bin/rails and rspec
      app/controllers/api/   assemble, graph, policies, workflows, proposals, requests, insights, trust, agent
      app/channels/          AssembleChannel, AgentChannel, EvalChannel
      app/jobs/              AssembleJob, CompilePolicyJob, ImpactJob, EvalRunJob, AgentJob
      app/models/            Person, Policy, Rule, Workflow, Request, ChangeProposal, AgentRun ...
      app/services/
        org/                 resolver.rb, graph_snapshot.rb
        rules/               engine.rb, condition.rb, conflict_detector.rb
        workflows/           runtime.rb, generator.rb
        assemble/            csv_mapper.rb, policy_extractor.rb, workflow_generator.rb
        agent/               runner.rb, tools/*.rb
        impact/              analyzer.rb, backtester.rb
        insights/            query_builder.rb, interpreter.rb
        evals/               runner.rb, judge.rb, stability.rb
        llm/                 client.rb, prompts.rb, schema_registry.rb
      app/mcp/               keel_server.rb, tools/*.rb
      spec/                  resolver_spec, engine_spec, analyzer_spec, query_builder_spec
    web/                     Vite + React + TypeScript
      src/routes/            assemble, graph, policies, workflows, proposals, inbox, insights, trust
      src/components/        CommandBar, TraceDrawer, OrgCanvas, RuleCard, ImpactReport ...
      src/lib/               api.ts (typed client), cable.ts, queryClient.ts
  packages/
    schemas/                 rule, workflow, insight-query, csv-mapping, change-proposal .schema.json
    api-types/               types generated from schemas + hand-written response types
  fixtures/                  factorial_people.csv, factorial_handbook.pdf, evals/*.yml
```

Rails loads every schema from `packages/schemas` at boot through `Llm::SchemaRegistry` and validates with `json_schemer`; `pnpm gen:types` regenerates the TypeScript types from the same files. Change a schema once and both sides follow, and a CI step fails if the generated types are stale. This shared-contract package is the main reason the monorepo is worth it, and a good point for the README.

### Request lifecycle: an AI action

Using "Move Sales under Ada" as the example:

1. The command bar posts the message to `AgentController#create`, which creates an `AgentRun` and enqueues `AgentJob`. The controller returns immediately with the run ID.
2. The browser subscribes to `AgentChannel` for that run ID.
3. `AgentJob` calls `Agent::Runner`, which sends the message plus tool definitions to the LLM.
4. The LLM chooses the `propose_org_change` tool with structured arguments. Each tool call is saved as an `AgentStep` and broadcast to the channel, so the trace drawer fills live.
5. The tool creates a `ChangeProposal` and runs `Impact::Analyzer` synchronously (it is fast and deterministic).
6. The final agent message links to the proposal. The user opens it, reviews the diff and impact, and clicks Approve.
7. `ProposalsController#approve` applies the diff in a database transaction and records who approved it.

The key point: the LLM's only output was a structured proposal. The human and the deterministic code did everything else.

## 4. Data model

Keel needs 16 tables in four groups: the company graph, the rules layer, the runtime, and the AI audit trail. Relational columns hold things you filter and join on; `jsonb` holds structured documents the LLM produces.

### Company graph

| Table | Key columns | Notes |
| --- | --- | --- |
| `companies` | name, locale, settings (jsonb) | One row for the demo; keeps the door open for multi-tenancy |
| `departments` | company\_id, name, head\_id | head\_id points to a person |
| `people` | company\_id, department\_id, manager\_id, name, email, title, location, start\_date, roles (text\[\]) | manager\_id is a self-reference; roles holds tags like `finance_lead`, `it_admin` |
| `import_issues` | company\_id, row\_number, field, raw\_value, message, resolved (bool) | Rows the CSV mapper was unsure about |

### Rules layer

| Table | Key columns | Notes |
| --- | --- | --- |
| `source_documents` | company\_id, filename, kind, page\_count | The uploaded handbook |
| `chunks` | source\_document\_id, page, position, text, embedding (vector 1536) | Handbook split into \~400-token pieces |
| `policies` | company\_id, title, category (leave, expense, remote, equipment, onboarding), status (draft, active), version | A policy groups rules |
| `rules` | policy\_id, key, conditions (jsonb), actions (jsonb), priority, source\_chunk\_id, source\_quote, ambiguities (jsonb), status | One executable rule; see schema below |
| `workflows` | company\_id, name, trigger (jsonb), steps (jsonb), version, status | Steps use role references, never person IDs |

### Runtime

| Table | Key columns | Notes |
| --- | --- | --- |
| `requests` | company\_id, requester\_id, kind (leave, expense, equipment), payload (jsonb), decision, matched\_rule\_ids (text\[\]), policy\_version, status | Payload holds amount, category, dates etc. |
| `workflow_runs` | request\_id, workflow\_id, current\_step, status | One per request |
| `step_runs` | workflow\_run\_id, step\_key, reference, resolved\_person\_id, status, acted\_at, overridden (bool), override\_reason | Override data feeds the eval loop |

### AI audit trail

| Table | Key columns | Notes |
| --- | --- | --- |
| `change_proposals` | company\_id, kind, title, diff (jsonb), impact (jsonb), proposed\_by (agent/user), agent\_run\_id, status, decided\_by, decided\_at | Every AI write goes through here |
| `agent_runs` / `agent_steps` | run: person\_id, message, final\_text, total\_tokens, cost\_usd; step: run\_id, position, kind (llm, tool), tool\_name, input, output, latency\_ms, tokens | The trace |
| `prompt_versions` | key (e.g. `policy_extractor`), version, template, model, active (bool) | Prompts live in the DB so evals can compare them |
| `eval_cases` / `eval_runs` / `eval_results` | case: suite, input, expected, source (manual, generated, override), status; run: suite, prompt\_version\_id, accuracy, stability, judge\_score, cost\_usd; result: run\_id, case\_id, passed, actual, diff | The Trust page |

### Rule schema (`rules.conditions` and `rules.actions`)

A rule is a condition tree plus an action. Conditions use `all` and `any` groups with simple comparisons, which is enough for real handbooks and simple to evaluate safely.

```json
{
  "key": "expense_conference_engineering",
  "applies_to": "expense",
  "priority": 10,
  "conditions": {
    "all": [
      { "field": "requester.department", "op": "eq",  "value": "Engineering" },
      { "field": "payload.category",     "op": "eq",  "value": "conference" },
      { "field": "payload.amount_eur",   "op": "lte", "value": 1000 }
    ]
  },
  "actions": { "decision": "auto_approve" },
  "source_quote": "Engineers attending conferences are automatically approved up to €1,000.",
  "ambiguities": [
    { "phrase": "attending conferences",
      "question": "Does the €1,000 cover travel and hotel, or only the ticket?",
      "options": ["Ticket only", "Ticket, travel and hotel"] }
  ]
}
```

Allowed operators: `eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `in`, `not_in`, `between`. Allowed fields are a fixed whitelist (`requester.department`, `requester.location`, `requester.tenure_months`, `payload.amount_eur`, `payload.category`, `payload.days`, `payload.notice_days`). The whitelist is enforced by the JSON Schema, so the LLM cannot invent fields the engine does not understand.

Allowed actions: `{"decision": "auto_approve"}`, `{"decision": "reject", "reason": "..."}`, or `{"decision": "require_approval", "approvers": ["manager_of(requester)", "role:finance_lead"]}`.

### Workflow schema (`workflows.steps`)

```json
{
  "trigger": { "request_kind": "equipment" },
  "steps": [
    { "key": "manager", "type": "approval", "assignee": "manager_of(requester)" },
    { "key": "it",      "type": "task",     "assignee": "role:it_admin", "title": "Order the laptop" },
    { "key": "finance", "type": "notify",   "assignee": "role:finance_lead",
      "when": { "field": "payload.amount_eur", "op": "gt", "value": 1500 } }
  ]
}
```

Step types: `approval` (blocks until approved or rejected), `task` (blocks until marked done), `notify` (fires and continues). The optional `when` uses the same condition format as rules, so one evaluator serves both.

## 5. Core engine: Org Resolver and Rules Engine

These two classes are the foundation. Every other component calls them, none of them call an LLM, and both should reach 100% test coverage on Friday night before any AI work begins.

### Graph snapshots

Both classes work on an in-memory `Org::GraphSnapshot` rather than querying the database row by row. A snapshot loads all people and departments for a company once (about 80 rows in the demo) into hashes keyed by ID. This has two benefits: resolution is instant, and impact analysis can apply a proposed change to a *copy* of the snapshot without touching the database.

```ruby
module Org
  class GraphSnapshot
    attr_reader :people, :departments

    def self.load(company)
      new(
        people: company.people.index_by(&:id).transform_values(&:attributes),
        departments: company.departments.index_by(&:id).transform_values(&:attributes)
      )
    end

    def initialize(people:, departments:)
      @people, @departments = people, departments
    end

    def with_change(diff)   # returns a new snapshot; never mutates self
      copy = GraphSnapshot.new(people: people.deep_dup, departments: departments.deep_dup)
      diff.each { |op| copy.apply!(op) }
      copy
    end

    def manager_of(id)        = people.dig(id, "manager_id")
    def holders_of(role)      = people.values.select { _1["roles"].include?(role) }.map { _1["id"] }
    def head_of_dept(dept_id) = departments.dig(dept_id, "head_id")
  end
end
```

### Org::Resolver

The resolver turns a reference string into person IDs. It returns a result object rather than raising, because "could not resolve" is an expected outcome that impact analysis needs to report.

```ruby
module Org
  class Resolver
    Result = Data.define(:person_ids, :error)

    def initialize(snapshot) = @g = snapshot

    def resolve(reference, requester_id:)
      ids = case reference
            when "requester"                      then [requester_id]
            when "manager_of(requester)"          then [@g.manager_of(requester_id)]
            when "skip_manager_of(requester)"     then [@g.manager_of(@g.manager_of(requester_id))]
            when "head_of(requester.department)"  then [@g.head_of_dept(@g.people.dig(requester_id, "department_id"))]
            when /\Arole:(\w+)\z/                 then @g.holders_of($1)
            else return Result.new([], "unknown reference #{reference}")
            end.compact

      return Result.new([], "#{reference} resolved to nobody") if ids.empty?
      return Result.new(ids, "self-approval") if ids == [requester_id] && reference != "requester"
      Result.new(ids, nil)
    end
  end
end
```

Note the self-approval check. In the reorg demo, Keel catches a case where someone would approve their own request, which is a real compliance problem and a satisfying moment on video.

### Rules::Engine

The engine evaluates a request against a policy's active rules and returns a decision, the matched rules, and the resolved approvers.

The algorithm:

1. Build a flat **context** hash from the request: `requester.department`, `requester.tenure_months`, `payload.amount_eur` and so on.
2. Evaluate every rule's condition tree against the context.
3. Among matching rules, take the highest `priority`. If priorities tie, the most restrictive action wins (reject beats require\_approval beats auto\_approve). This tie rule is documented and tested, because it is a real policy decision.
4. If no rule matches, fall back to the policy's default action (normally `require_approval` from the manager).
5. Resolve approver references through `Org::Resolver`. If any fail, the decision becomes `blocked` with the reason attached.

```ruby
module Rules
  class Engine
    Decision = Data.define(:outcome, :rule_keys, :approvers, :errors, :explanation)
    SEVERITY = { "reject" => 3, "require_approval" => 2, "auto_approve" => 1 }.freeze

    def initialize(snapshot) = (@g = snapshot; @resolver = Org::Resolver.new(snapshot))

    def evaluate(request, rules)
      ctx     = Context.build(request, @g)
      matched = rules.select { Condition.match?(_1.conditions, ctx) }
      winner  = matched.max_by { [_1.priority, SEVERITY[_1.actions["decision"]]] }
      action  = winner&.actions || { "decision" => "require_approval", "approvers" => ["manager_of(requester)"] }

      approvers, errors = resolve_all(action["approvers"] || [], request.requester_id)
      outcome = errors.any? ? "blocked" : action["decision"]

      Decision.new(outcome, matched.map(&:key), approvers, errors, Explainer.call(winner, ctx))
    end
  end
end
```

`Condition.match?` is a small recursive function: an `all` node requires every child to match, an `any` node requires one, and a leaf compares `ctx[field]` with `value` using the operator. `Explainer` builds a plain-English sentence from the winning rule, for example: "Auto-approved because you are in Engineering, the category is conference, and €900 is within the €1,000 limit (Handbook p.4)." No LLM is needed for explanations at runtime.

### Test plan for the engine

| Case | Expected |
| --- | --- |
| Engineer, conference, €900 | auto\_approve, rule `expense_conference_engineering` |
| Engineer, conference, €1,200 | require\_approval, manager |
| Sales, travel, €2,500 | require\_approval, manager + finance lead |
| Any, €300 | auto\_approve under the small-expense rule |
| Requester is the finance lead, €2,500 | blocked, self-approval |
| Requester has no manager (CEO) | blocked, resolved to nobody |
| Two rules match with equal priority | the more restrictive one wins |
| Leave, 3 days, 2 days' notice | reject, notice period rule |

Write these as RSpec examples first, then make them pass. They double as documentation of how policies behave.

## 6. Assemble pipeline

Assemble turns two uploads into a working company in about 60 seconds, streaming every step to the screen. It is the opening shot of the demo, so it must look alive.

### Stages

`AssembleJob` runs five stages in order and broadcasts an event on `AssembleChannel` after each meaningful unit of work.

**Stage 1: CSV mapping (`Assemble::CsvMapper`).** The CSV's header row and the first 10 data rows go to the LLM with a JSON Schema asking for a mapping from each source column to a Keel field (`name`, `email`, `title`, `department`, `manager`, `location`, `start_date`, or `ignore`), plus a confidence for each. For example, the headers `Full Name, E-mail, Job Title, Dept, Line Mgr, Office, Joined` map cleanly; a column called `Grp` might map to `department` with confidence 0.55 and be flagged.

The mapping is then applied in plain Ruby to every row. The LLM only sees a sample; it never processes all 80 rows, which keeps cost and latency low and avoids hallucinated rows.

**Stage 2: Graph building (deterministic).** Ruby creates departments and people. Managers are matched by email first, then by exact name, then by fuzzy name (Levenshtein distance ≤ 2, which catches typos like "Tunde Bakre" vs "Tunde Bakare"). Anything ambiguous becomes an `import_issue` for the user to resolve. Each person created broadcasts a `person_added` event, so the org chart grows node by node on screen.

**Stage 3: Handbook chunking.** `pdf-reader` extracts text per page. Text is split into chunks of roughly 400 tokens on paragraph boundaries, each tagged with its page number, and embedded with `ruby_llm` into the pgvector column. Embeddings are used later by the agent to find relevant handbook passages.

**Stage 4: Policy extraction (`Assemble::PolicyExtractor`).** For each policy category (leave, expense, remote work, equipment, onboarding), Keel retrieves the most relevant chunks by vector search and asks the LLM to extract rules in the schema from section 4. The prompt has three hard requirements:

- Every rule must include a `source_quote` copied verbatim from the provided chunks. After the response, Ruby checks that the quote actually appears in the chunk text. If it does not, the rule is rejected and logged as a hallucination. This one check is a strong talking point in interviews.
- Every vague phrase must appear in `ambiguities` with a question and options, rather than being guessed.
- Only whitelisted fields and operators may be used; the JSON Schema enforces this.

Each extracted rule broadcasts a `rule_extracted` event, and the policy list fills in live.

**Stage 5: Workflow generation (`Assemble::WorkflowGenerator`).** For each request kind that has policies (leave, expense, equipment), Keel generates a default workflow using role references. Approval steps come straight from the rules' `require_approval` actions; the LLM only adds sensible task and notify steps. The output is validated and saved as a draft.

### Event format

```json
{ "stage": "graph", "event": "person_added",
  "data": { "id": 42, "name": "Ngozi Eze", "manager_id": 17, "department": "Sales" },
  "progress": 0.38 }
```

The frontend keeps an append-only list of events and derives the view from it: the org canvas adds nodes, the policy panel adds cards, and the progress bar follows `progress`.

### Failure handling

Each stage is idempotent and records its completion on the company record, so a failed job can be retried from the last finished stage. LLM calls use `ruby_llm` with a schema; if validation fails, Keel retries once with the validation errors appended to the prompt ("Your output failed: rule 3 uses unknown field payload.cost"). A second failure marks that policy as `needs_review` rather than crashing the pipeline. Graceful partial success is better than an all-or-nothing demo.

## 7. Policies component

The Policies page shows the handbook and the rules compiled from it side by side, so a non-technical HR manager can check that the machine understood them. Its job is trust: every rule visibly comes from somewhere, and nothing vague goes live unresolved.

### Policy detail view

The page is split into two panes. On the left is the handbook text for that policy's source chunks, with page numbers. On the right is a list of **rule cards**. Each card shows the rule in plain English (generated deterministically from the conditions, for example "If department is Engineering and category is conference and amount ≤ €1,000 → auto-approve"), the priority, and a status chip.

Hovering a card highlights its `source_quote` in the left pane and scrolls to it. Clicking "Show JSON" reveals the raw rule for engineers. A small "Test this policy" box lets the user type a scenario (department, category, amount) and see `Rules::Engine` evaluate it instantly, with the matched rule highlighted.

### Ambiguity resolution

Rules with open ambiguities show an amber banner: "Does the €1,000 cover travel and hotel, or only the ticket?" with the options as buttons. Choosing an option sends the original rule, the question and the answer to the LLM, which returns an updated rule (for example, adding a `payload.category in [conference_ticket]` condition). The update is shown as a before-and-after diff and saved as a new rule version.

A policy cannot move from `draft` to `active` while any rule has unresolved ambiguities. This is a deliberate friction point, and the README should explain why: guessing silently is how AI features lose trust.

### Conflict detection (`Rules::ConflictDetector`)

Conflicts are found deterministically, with no LLM involved. For each pair of rules that apply to the same request kind, the detector generates **probe requests**: boundary values for every numeric threshold that appears in either rule (for example 499, 500, 501, 999, 1000, 1001 for amounts), crossed with each department and category mentioned. It runs both rules against every probe. If both match a probe and their actions differ while their priorities are equal, that is a conflict.

For example, the travel policy says "travel under €800 is auto-approved" and the expense policy says "any expense over €500 needs manager approval". The probe `{category: travel, amount: 650}` matches both with different outcomes, so Keel reports: "Conflict between Travel rule T2 and Expense rule E1 for travel expenses between €501 and €799."

The LLM is used only afterwards, to write a one-sentence plain-English explanation and suggest a resolution (usually raising one rule's priority). The suggestion becomes a Change Proposal.

### Rule lifecycle

1. **Extracted** (draft, may have ambiguities)
2. **Resolved** (all ambiguities answered)
3. **Active** (policy published; used by the engine)
4. **Superseded** (replaced by a newer version; kept for audit and backtesting)

Rules are never edited in place. Each change creates a new version, and every `request` stores the `policy_version` it was decided under. This is what makes backtesting and audit possible later.

## 8. Workflows component and runtime

Workflows move a request from submission to done. Definitions use role references, and the runtime resolves them at each step, so a workflow written once keeps working through every reorg.

### How a request flows through the system

When a request is created (from the UI, the agent, or MCP), `Workflows::Runtime.start(request)` runs these steps:

1. **Decide.** Call `Rules::Engine.evaluate`. Save `decision`, `matched_rule_ids` and `policy_version` on the request.
2. **Short-circuit.** If the decision is `auto_approve`, mark the request approved, record a single system step, and stop. If it is `reject` or `blocked`, record the reason and stop.
3. **Pick a workflow.** Find the active workflow whose `trigger.request_kind` matches.
4. **Merge approvers.** The engine's `approvers` become the workflow's approval steps, in order. This keeps the rules as the source of truth for *who must approve*, while the workflow adds *what else happens* (tasks and notifications).
5. **Create step runs.** For each step whose `when` condition matches, create a `step_run` with its reference string, unresolved.
6. **Advance.** Resolve the first pending step's reference now, assign it, and wait.

### Advancing steps

`Workflows::Runtime.act(step_run, action:, actor:)` handles approve, reject, and complete:

- **approve / complete**: mark the step done, then resolve and assign the next pending step. Notify steps are resolved and marked done immediately, and the runtime moves on. When no steps remain, the request is approved.
- **reject**: mark the request rejected; remaining steps are cancelled.
- **override**: an approver can approve something the engine rejected, or reject something it auto-approved, with a required reason. This sets `overridden: true` and creates a candidate eval case (see section 12).

Resolving each step **at the moment it becomes active**, rather than when the request is created, is a deliberate choice. If a manager changes mid-way through a two-week leave request, the next step goes to the new manager. Write this in an ADR.

### Workflow builder UI

The workflow page shows the steps as a left-to-right React Flow graph: a trigger node, then one node per step coloured by type (approval blue, task green, notify grey), with conditional steps drawn with a dashed edge and their condition as the edge label.

Above the graph is a text box: "Describe a change". Typing "Add a step where IT sets up accounts after the manager approves, and notify the office manager if the person is in Lagos" sends the current workflow JSON and the instruction to `Workflows::Generator`. The LLM returns a complete new workflow in the schema. Keel validates it, computes a step-level diff, and creates a Change Proposal. The page shows the proposed graph with added nodes outlined in green and removed nodes in red.

### Test run

A "Test run" button opens a form to choose a requester and fill in a payload. The runtime executes in **dry-run mode** against the current snapshot: nothing is saved, and each step lights up in sequence on the graph with the resolved person's name and avatar. This takes about an hour to build and looks excellent on video.

### Inbox

Each person has a simple inbox (`/inbox?as=<person>`) listing step runs assigned to them, with Approve and Reject buttons and an override reason field. A person switcher in the header lets you act as anyone, which is how you demo the full loop alone.

## 9. Agent and command bar

The agent is a single ⌘K command bar that can answer questions, take actions, and propose changes, using tools that wrap the deterministic services. The agent never decides outcomes itself; it chooses tools and explains their results.

### Three kinds of request

| Kind | Example | What happens |
| --- | --- | --- |
| Ask | "Can I expense a €1,200 flight to RubyConf?" | Agent calls `check_policy`; engine returns the decision; agent explains it and cites the handbook page |
| Act | "Request leave for 22–29 December" | Agent calls `create_request`; the runtime starts the workflow; agent reports who must approve |
| Change | "Move Sales under Ada" or "Raise the auto-approve limit to €800" | Agent calls `propose_org_change` or `propose_rule_change`; a Change Proposal with impact is created; agent links to it |

The agent always acts as the person selected in the header switcher, so "my leave" means that person's leave and permissions are respected (only people with the `hr_admin` role can propose changes).

### Tools

Each tool is a Ruby class with a name, a description written for the model, a JSON Schema for its arguments, and a `call` method. `ruby_llm` turns these into the provider's tool format.

| Tool | Arguments | Wraps |
| --- | --- | --- |
| `search_people` | query | Name, title or department lookup |
| `org_lookup` | person\_id | Manager, reports, department, roles |
| `who_approves` | request\_kind, payload | Dry-run of engine + runtime; returns approver chain |
| `check_policy` | request\_kind, payload | `Rules::Engine.evaluate` with explanation and citations |
| `search_handbook` | query | Vector search over chunks; returns quotes with page numbers |
| `create_request` | request\_kind, payload | Creates a request and starts the workflow |
| `list_my_requests` | status? | The current person's requests and their step status |
| `propose_org_change` | operations\[\] (move\_person, change\_manager, set\_department\_head, assign\_role) | Creates a Change Proposal and runs impact analysis |
| `propose_rule_change` | policy\_id, instruction | Recompiles the affected rule; creates a proposal with backtest |
| `run_insight` | question | Hands off to the Insights interpreter (section 11) |

### The agent loop (`Agent::Runner`)

1. Build the system prompt: who the current person is (name, title, department, manager, roles), today's date, the company name, and the rules of behaviour: always use tools for facts, never state a policy outcome without `check_policy`, never claim a change happened when only a proposal exists, and cite handbook pages.
2. Send the conversation and tool definitions to the model.
3. If the model returns tool calls, execute them, save each as an `agent_step` with input, output and latency, broadcast to `AgentChannel`, and send the results back.
4. Repeat until the model returns a final text answer, with a hard limit of 8 iterations to prevent loops.
5. Save the final text, token totals and cost on the `agent_run`.

Write tools are idempotent per run (a duplicate `create_request` in the same run returns the existing request), because models sometimes repeat calls.

### Trace drawer

A drawer on the right of the command bar shows the run as a vertical timeline. Each step shows an icon (model or tool), the tool name, a collapsible JSON view of input and output, latency in milliseconds, and tokens. A footer shows total cost, for example "4 steps · 2.1 s · 3,412 tokens · $0.006". Recruiters and engineers both like seeing an agent's reasoning made inspectable.

### Feedback

Each final answer has thumbs up and thumbs down. A thumbs down asks "What was wrong?" with options (wrong answer, wrong action, unclear, other) and creates a candidate eval case containing the message, the trace, and the user's note.

## 10. Change proposals and impact analysis

Every change to the org, a rule or a workflow, whether proposed by the agent or a person, becomes a proposal with a computed impact report, and only a human can apply it. This is the centre of the human-oversight story and the most impressive screen in the demo.

### Proposal kinds and diffs

| Kind | Diff format (stored in `diff` jsonb) |
| --- | --- |
| `org` | List of operations: `{op: "change_manager", person_id: 31, from: 12, to: 7}`, `{op: "set_department_head", department_id: 3, to: 7}`, `{op: "assign_role", person_id: 22, role: "finance_lead"}` |
| `rule` | `{policy_id, before: [rules], after: [rules]}` |
| `workflow` | `{workflow_id, before: {...}, after: {...}}` |

Org diffs are operations rather than before-and-after snapshots so they can be applied to a graph snapshot and replayed.

### Impact::Analyzer for org changes

The analyzer answers one question: "If we apply this, whose requests will route differently, and will anything break?" It does this without any LLM:

1. Load the current snapshot `A` and build `B = A.with_change(diff)`.
2. For every person, and for every request kind with a representative payload (for example a €100, €800 and €3,000 expense, and a 5-day leave), run the engine and runtime in dry-run mode against both `A` and `B`.
3. Compare the resolved approver chains. Classify each difference:
   - **Rerouted**: chain changed but resolves fully ("Ngozi's expenses now go to Ada instead of Tunde").
   - **Broken**: a reference resolves to nobody in `B` ("Sales has no department head").
   - **Self-approval**: someone would approve their own request.
   - **Approval load change**: count of chains each approver appears in, before and after ("Ada goes from 6 to 21 approval chains").
4. Also check open requests: in-flight step runs whose next step would now resolve to someone else.

With 80 people and about 10 scenarios each, that is 800 engine evaluations per snapshot, which runs in well under a second in Ruby. Say this in the README: deterministic analysis is fast enough to run on every proposal.

### Backtesting for rule changes (`Impact::Backtester`)

For a rule proposal, the backtester replays every historical request of that kind (the seed data includes 3 months of history) against the old and new rule sets and reports flipped decisions:

> "Raising the auto-approve limit from €500 to €800 would have changed 23 of 412 past expense decisions: 23 would have been auto-approved instead of sent to a manager. This would have saved roughly 46 manager approvals over 3 months."

The numbers are computed; only the final sentence is phrased by a template, not an LLM.

### The proposal page

The page is designed for an HR manager, not an engineer:

- **Header**: the title ("Move Sales under Ada Nwosu"), who proposed it ("Keel agent, on behalf of Ifeoma"), and status.
- **Summary cards**: rerouted count, broken count (red when above zero), self-approval count, and decisions flipped.
- **Diff**: for org changes, a mini org chart with moved nodes highlighted; for rules, a side-by-side rule card diff; for workflows, the before-and-after graph.
- **Details**: an expandable table of every affected person and chain, filterable by category.
- **Plain-English explanation**: one paragraph generated by the LLM *from the computed impact JSON only*, so it cannot invent effects. For example: "This move gives Ada a lot more approval work and leaves Sales without a finance approver for large expenses. Consider assigning a finance contact for Sales first."
- **Actions**: Approve (disabled while there are broken chains, unless "Approve anyway" is ticked with a reason) and Reject.

### Applying a proposal

Approval runs inside a database transaction: re-run the analyzer against the *current* graph (it may have changed since the proposal was made), refuse if the impact differs materially, apply the operations, bump versions, and record `decided_by` and `decided_at`. Rejections with a reason become candidate eval cases for the agent suite.

## 11. Insights: natural-language analytics

Insights answers questions like "Which teams had the most leave days last quarter?" by having the LLM fill in a typed query object, which Ruby validates and runs through ActiveRecord. The LLM never writes SQL, so it cannot run arbitrary queries or leak data across companies.

### The query object

```json
{
  "metric": "approval_load",
  "aggregation": "count",
  "group_by": "approver",
  "filters": [ { "field": "request.kind", "op": "eq", "value": "expense" } ],
  "time_range": { "from": "2026-07-01", "to": "2026-09-30" },
  "sort": "desc",
  "limit": 10,
  "chart": "bar"
}
```

The schema allows a fixed set of metrics, each backed by a hand-written scope in `Insights::QueryBuilder`:

| Metric | Meaning | Group-by options |
| --- | --- | --- |
| `request_count` | Number of requests | department, kind, month, decision |
| `leave_days` | Total approved leave days | department, person, month |
| `expense_total` | Sum of approved expense amounts (€) | department, category, month |
| `approval_load` | Pending or completed approval steps per person | approver, department |
| `time_to_decision` | Median hours from submission to final decision | department, kind |
| `override_rate` | Share of decisions overridden by humans | rule, policy, month |
| `auto_approval_rate` | Share of requests auto-approved | policy, month |

### Flow

1. The user types a question on `/insights` or asks the agent, which calls `run_insight`.
2. `Insights::Interpreter` sends the question, today's date, the list of departments and categories, and the schema to the LLM. It returns a query object, or a clarifying question when the request is ambiguous ("Do you mean calendar Q3 or your fiscal quarter?").
3. The object is validated against the schema. Unknown metrics or fields are rejected with a friendly message listing what is available.
4. `Insights::QueryBuilder` maps it to ActiveRecord: `metric` selects a base scope, `filters` become `where` clauses from a whitelist, `group_by` becomes `group`, and every query is scoped to the current company.
5. The result comes back as rows. The frontend draws it with Recharts using the `chart` hint, shows the query object as small chips ("Expense · Jul–Sep 2026 · by approver") so the user can see how the question was understood, and shows a one-line summary.

Showing the interpreted query as chips is an important detail. It turns a non-deterministic step into something a user can check at a glance, which is exactly the JD's point about making probabilistic outputs something a team can reason about.

### Suggested questions

The empty state offers four example questions as buttons so the demo never starts with a blank box: "Who is overloaded with approvals this month?", "Leave days by department last quarter", "How often do managers override the expense policy?", "Median time to approve an expense by department".

## 12. Trust: eval harness

The Trust page proves Keel's AI parts work, measures how consistent they are, and shows the loop where real human corrections become new tests. This section answers the JD's sentence "evaluating them in production is the hard part" directly, so it is never cut.

### Three eval suites

| Suite | Cases | Input | Expected | How it is scored |
| --- | --- | --- | --- | --- |
| `policy_extraction` | \~25 | A handbook passage | The rules it should produce, plus expected ambiguities | Decision accuracy on probe requests (below), quote verification, ambiguity recall |
| `agent` | \~15 | A message + acting person | Expected tool(s) called and expected outcome | Tool selection match, outcome match, LLM-as-judge on answer quality |
| `insights` | \~10 | A question | Expected query object | Field-by-field match of metric, group\_by, filters, time range |

### Scoring compiled rules by behaviour, not text

Comparing compiled JSON to expected JSON is too strict: two different rule sets can behave identically. Instead, Keel scores **behaviour**. For each extraction case, it generates probe requests (as in conflict detection) and runs both the expected rules and the compiled rules through `Rules::Engine`. The score is the share of probes where the decisions and approvers match.

For example, if the expected rule auto-approves engineering conference spend up to €1,000 and the compiled rule mistakenly uses `lt` instead of `lte`, the two disagree only on the €1,000 probe. The case scores 96% and the failure diff shows exactly that probe. This is a strong interview point: it turns a fuzzy LLM output into a precise, explainable number.

### Measuring non-determinism: compile stability

For each extraction case, Keel compiles the same passage 5 times at the production temperature and measures pairwise behavioural agreement across the 5 outputs. A stability of 100% means the model gives functionally identical rules every time; 80% means one run in five behaves differently on some probes.

This gives the team a single number for "how much can we trust this to be consistent?", and it often reveals vague prompt wording before users do.

### LLM-as-judge for agent answers

For agent cases, a separate model call grades the final answer against a short rubric, returning JSON scores from 1 to 5 for: correctness against the tool results, citation of the handbook where relevant, clarity for a non-technical employee, and not claiming actions that did not happen. The judge sees the tool outputs, so it grades faithfulness, not general knowledge. To keep the judge honest, 5 cases have hand-labelled scores, and the page shows judge agreement with those labels.

### Prompt versions and the comparison view

Prompts live in `prompt_versions`. An eval run picks a suite and a prompt version, runs every case in `EvalRunJob` (streaming progress on `EvalChannel`), and stores per-case results. The Trust page shows:

- A scoreboard per suite: accuracy, stability, judge score, average latency and cost per case, for the active prompt and any challenger.
- A side-by-side comparison of two runs, with a list of cases that **flipped** (passed in one, failed in the other).
- A failure drill-down: input, expected, actual, the probes that disagreed, and the diff.
- A line chart of accuracy across prompt versions over time.
- A "Promote" button that makes a challenger the active prompt. It is disabled if the challenger regresses any case that the current version passes, unless you confirm.

For the demo, write a deliberately weaker v1 prompt (no instruction on verbatim quotes and no ambiguity guidance) and a stronger v2, so the comparison shows a real, explainable improvement.

### The production feedback loop

Three production signals create **candidate** eval cases automatically: an approver overriding an engine decision (with reason), a thumbs-down on an agent answer, and a rejected Change Proposal. Candidates appear in a review queue on the Trust page. A reviewer edits the expected outcome if needed and clicks "Add to suite". The next eval run includes it.

This closes the loop described in the JD: build, deploy, measure, adjust. The analytics side reports `override_rate` per rule, which tells you which rules to look at first.

## 13. MCP server

Keel exposes four of its tools over the Model Context Protocol, so any MCP client (Claude Desktop, Copilot, Factorial One in principle) can ask Keel questions and file requests. This mirrors Factorial's YepCode acquisition, whose stated purpose is letting their agents discover and run workflows as MCP tools.

### Exposed tools

| MCP tool | Reuses | Notes |
| --- | --- | --- |
| `who_approves` | Agent tool of the same name | Read-only |
| `check_policy` | Agent tool of the same name | Read-only; returns decision, explanation, handbook page |
| `org_lookup` | Agent tool of the same name | Read-only |
| `request_leave` | `create_request` with kind `leave` | The only write; creates a real request that goes through the normal workflow and approvals |

The MCP tools are thin adapters over the same Ruby tool classes the internal agent uses. One implementation, two front doors. Mention this in the README as an example of avoiding duplicated logic.

### Implementation sketch

Use the official Ruby SDK (`gem "mcp"`), mounted inside Rails over its streamable HTTP transport at `/mcp`. The shape is roughly:

```ruby
# app/mcp/tools/check_policy_tool.rb
class CheckPolicyTool < MCP::Tool
  description "Check what Keel's company policy says about a request, e.g. an expense or leave."
  input_schema(
    properties: {
      request_kind: { type: "string", enum: %w[expense leave equipment] },
      payload:      { type: "object" }
    },
    required: %w[request_kind payload]
  )

  def self.call(request_kind:, payload:, server_context:)
    person = server_context[:person]
    result = Agent::Tools::CheckPolicy.new(person).call(request_kind:, payload:)
    MCP::Tool::Response.new([{ type: "text", text: result.to_json }])
  end
end
```

Check the gem's README on Friday for the exact class and transport names, since the SDK is still evolving.

### Authentication

For the demo, each person has a personal access token on their profile page. The MCP endpoint reads it from the `Authorization: Bearer` header and sets `server_context[:person]`, so "my leave" means that person. Tokens are hashed in the database. In the README, note that production would use OAuth, which MCP supports.

### Connecting Claude Desktop

Add Keel as a custom connector pointing at `https://keel.yourdomain.com/mcp` with the token, or bridge it through a local stdio proxy in `claude_desktop_config.json` if your plan doesn't support remote connectors. Then record: "Who approves my leave if I take next week off?" Claude calls `who_approves`, Keel answers "Tunde Bakare, then Ada Nwosu," and the Keel trace drawer shows the same call arriving. Seeing an external agent use your product is a strong closing shot.

## 14. Frontend architecture

The frontend is a React + TypeScript single-page app in `apps/web` that talks to the Rails API over JSON and receives live updates over Action Cable. It should look like a calm, real B2B product, because "things people actually want to use" is in the job description.

### How the frontend talks to the API

All requests go through one typed client in `src/lib/api.ts`, whose request and response types come from `packages/api-types`. TanStack Query wraps it: queries for reads (for example `useQuery({ queryKey: ['policy', id], queryFn: () => api.policies.get(id) })`), mutations for writes, and cache invalidation after an approval so the graph and inbox refresh.

In development, Vite proxies `/api` and `/cable` to Rails on port 3000, so the browser sees one origin and CORS never comes up. In production, the reverse proxy routes the same paths to the API service, with `rack-cors` as a fallback if you serve the two on different domains.

The acting person (from the person switcher) is sent as a bearer token on every request and as a parameter on the Action Cable connection, so the API always knows who is asking.

Live data uses a small hook:

```ts
function useChannel<T>(channel: string, params: object, onEvent: (e: T) => void) {
  useEffect(() => {
    const sub = consumer.subscriptions.create({ channel, ...params }, { received: onEvent })
    return () => sub.unsubscribe()
  }, [channel, JSON.stringify(params)])
}
```

### Pages

| Route | Page | Main components | Live channel |
| --- | --- | --- | --- |
| `/assemble` | Assemble | `UploadDropzone` ×2, `OrgCanvas` (growing), `PolicyFeed`, `ImportIssues`, progress bar | `AssembleChannel` |
| `/graph` | Graph | `OrgCanvas` with overlay toggles, `PersonPanel` | none |
| `/policies`, `/policies/:id` | Policies | `PolicyList`, `HandbookPane`, `RuleCard`, `AmbiguityBanner`, `PolicyTester`, `ConflictList` | none |
| `/workflows/:id` | Workflow | `FlowCanvas`, `DescribeChangeBox`, `TestRunDialog` | none |
| `/proposals`, `/proposals/:id` | Proposals | `ImpactSummaryCards`, `OrgDiffCanvas` / `RuleDiff` / `FlowDiff`, `AffectedTable`, `ApproveBar` | none |
| `/inbox` | Inbox | `StepRunList`, `OverrideDialog` | none |
| `/insights` | Insights | `QuestionBox`, `QueryChips`, `InsightChart`, `SuggestedQuestions` | none |
| `/trust` | Trust | `Scoreboard`, `RunCompare`, `FailureDrilldown`, `AccuracyTrend`, `CandidateQueue` | `EvalChannel` |
| global | Layout | `CommandBar` (cmdk), `TraceDrawer`, `PersonSwitcher`, sidebar nav | `AgentChannel` |

### Key components

**`OrgCanvas`** uses React Flow with a top-down tree layout computed by `dagre`. Nodes show avatar initials, name, title and department colour. Overlays are props that change node styling: `approvalLoad` colours nodes from neutral to red by chain count, `broken` outlines people with unresolvable approvers, and `highlight` pulses moved nodes in a diff. During Assemble, new nodes fade and scale in as `person_added` events arrive.

**`CommandBar`** is cmdk opened with ⌘K. Typing shows quick actions (go to page, switch person) and, on Enter, sends the text to the agent. The answer streams into the bar, and links such as "View proposal" are rendered as buttons. A small button opens the `TraceDrawer`.

**`TraceDrawer`** is a shadcn `Sheet` rendering `agent_steps` as a timeline with collapsible JSON (use a lightweight JSON viewer), latency and token badges, and a cost footer.

**`ImpactSummaryCards`** are four large-number cards (rerouted, broken, self-approval, decisions flipped). Broken and self-approval cards turn red when above zero, and clicking a card filters the affected table.

### Design system

Use shadcn/ui on Tailwind with a neutral zinc palette, one accent colour (a deep teal works well and is distinct from Factorial's brand), Inter or Poppins for UI text, and a monospace face for JSON. Every page gets a designed empty state and loading skeleton. Support dark mode with Tailwind's `dark:` classes; it costs little and looks polished on video.

Two small details make it feel like a product: keyboard shortcuts shown in tooltips (G then P for Policies, ⌘K for the agent), and toasts that confirm actions in plain language ("Proposal approved. 14 approval chains updated.").

## 15. End-to-end user flows

Five flows cover everything the demo shows. Each is written as what the user does, then what the system does underneath, so you can test them one by one on Sunday.

### Flow A: Assemble a company from scratch

1. Beatriz (HR admin) opens `/assemble` and drops `factorial_people.csv` and `factorial_handbook.pdf`.
2. `AssembleJob` starts; the page subscribes to `AssembleChannel`.
3. The CSV mapper returns a column mapping; `Grp` is flagged at 0.55 confidence. The import issues panel shows it.
4. People appear on the org canvas one by one. Two manager names fail exact matching; one is fixed by fuzzy matching, one becomes an issue.
5. Handbook pages are chunked and embedded; policy cards appear as rules are extracted. One rule fails quote verification and is dropped with a log line.
6. Default workflows are generated. The page ends on a summary: "78 people, 9 departments, 5 policies, 23 rules (4 need your input), 3 workflows."
7. Ifeoma resolves the two import issues and clicks "Go to policies".

### Flow B: Resolve an ambiguity and publish a policy

1. On the Expense policy, an amber banner asks whether the €1,000 conference limit includes travel.
2. Ifeoma picks "Ticket only". Keel recompiles that rule and shows a before-and-after diff.
3. She types a scenario in the tester (Engineering, conference ticket, €950) and sees "Auto-approved" with the rule highlighted.
4. The conflict list shows one conflict between Travel and Expense rules. She accepts the suggested fix, which creates and approves a small rule proposal.
5. With no open ambiguities, "Publish" is enabled. The policy becomes active as version 2.

### Flow C: An employee asks and acts through the agent

1. Using the person switcher, act as Ngozi (Sales). Press ⌘K: "Can I expense a €1,200 client dinner?"
2. The agent calls `check_policy`. The engine returns `require_approval` from Tunde (manager) because the amount exceeds €500. The agent explains this and cites page 4.
3. Ngozi says "OK, submit it." The agent calls `create_request`. The runtime starts the workflow and assigns Tunde.
4. The trace drawer shows 3 steps, 1.8 s, and the cost.
5. Switch to Tunde, open `/inbox`, and approve. The request completes; the finance notification step fires because the amount exceeds the notify threshold.

### Flow D: A reorg with impact preview

1. Act as Ifeoma. ⌘K: "Ada is now Head of Operations and Sales reports to her."
2. The agent calls `search_people` to find Ada and the Sales department, then `propose_org_change` with two operations.
3. `Impact::Analyzer` compares the snapshots: 14 chains rerouted, 1 broken (large Sales expenses need `role:finance_lead`, but the Sales finance contact role was held by someone moving out), Ada's approval load goes from 6 to 21.
4. The agent replies with a summary and a "View proposal" button.
5. On the proposal page, Approve is disabled because of the broken chain. Ifeoma asks the agent to "Make Chioma the finance lead for Sales"; the proposal is updated and re-analysed: 0 broken.
6. She approves. The graph updates, and a toast reports the rerouted chains. Ngozi's next expense now routes to Ada.

### Flow E: Improve a prompt and prove it

1. Open `/trust`. The `policy_extraction` suite shows v1 at 78% accuracy and 82% stability.
2. Select v2 as challenger and click "Run". Progress streams; v2 finishes at 94% accuracy and 96% stability.
3. The comparison lists 6 cases fixed by v2 and 1 case that regressed. Drill into the regression: v2 used `lt` instead of `lte` on one threshold, visible in the probe diff.
4. The candidate queue holds 2 cases created from overrides during Flow C testing. Add them to the suite.
5. Promote v2. The accuracy trend chart gains a point.

## 16. Seed data

The demo runs on a fictional company, Demo Factorial, prepared on Friday so the rest of the weekend is spent on features. Good seed data makes every flow believable, so it is worth the two hours.

### Demo Factorial

A 28-person software company with offices in Barcelona, Madrid and Lisbon. Nine departments: Leadership, Engineering, Product, Sales, Customer Success, Marketing, Finance, People (HR), IT. The CEO has no manager, which gives the resolver a real edge case.

Set up the people so the demo flows work: Beatriz is the HR admin (signed in as `demo.hr@factorial.co`), Catarina is in Sales under Carlos, Carlos reports to the COO, Sofia is a Customer Success lead with 6 approval chains, Nuria is the finance lead, Alvaro is in Finance and eligible to take the Sales finance contact role, and Tiago is the IT admin.

### The messy CSV (`factorial_people.csv`)

Make it messy on purpose, in the ways real exports are:

- Headers: `Full Name, E-mail, Job Title, Grp, Line Mgr, Office, Joined`
- Managers listed by name, not ID, with one typo ("Carlos Martinz") and one name that matches two people
- Mixed date formats (`2023-04-01`, `01/04/2023`, `April 2023`)
- One duplicate row and one row missing an email

This gives the CSV mapper and import issues panel real work to show.

### The handbook (`factorial_handbook.pdf`)

About 6 pages with sections on leave, remote work, expenses, travel, equipment and onboarding. Draft it with an LLM, then edit it by hand to plant specific situations:

- **Clear thresholds** the extractor should get right: expenses over €500 need manager approval; over €2,000 also need the finance lead; leave needs 14 days' notice for more than 3 days.
- **Two deliberate ambiguities**: the conference allowance ("engineers attending conferences are automatically approved up to €1,000") and remote work ("remote work is generally allowed two days a week").
- **One deliberate conflict**: a travel section that auto-approves travel under €800, contradicting the €500 expense rule.
- **One trap for hallucination**: a paragraph about the company's history that contains numbers but no rules.

Save a Spanish version too if you have time; Factorial's customers write handbooks in Spanish, and running Assemble on it is a nice touch.

### History (`db/seeds/history.rb`)

Generate three months (July to September 2026) of past requests so Insights and backtesting have data: about 140 expense requests with amounts drawn from a long-tailed distribution (most €50–€400, some €1,000+), about 55 leave requests, and about 12 equipment requests. Run them through the real engine and runtime with randomised approval times, and mark roughly 5% as overridden with plausible reasons. This makes the override-rate chart and the candidate queue look real.

### Eval fixtures (`spec/fixtures/evals/*.yml`)

Write cases as YAML so they are easy to read and review. Example:

```yaml
- id: exp_conference_limit
  suite: policy_extraction
  input: "Engineers attending conferences are automatically approved up to €1,000."
  expected_rules:
    - conditions: { all: [ { field: requester.department, op: eq, value: Engineering },
                           { field: payload.category, op: eq, value: conference },
                           { field: payload.amount_eur, op: lte, value: 1000 } ] }
      actions: { decision: auto_approve }
  expected_ambiguities: [ "attending conferences" ]
```

## 17. Implementation plan

The build takes about 30 focused hours from Friday evening to Sunday night, ordered so the deterministic core is solid before any AI work and every block ends with something demoable. Tick tasks off as you go; each block ends with a milestone you can check.

### Friday evening (6 pm – midnight, \~6 h): foundation

- [ ] Create the monorepo: `pnpm-workspace.yaml` and root scripts (`dev` runs both apps in parallel, `test`, `gen:types`)
- [ ] `apps/api`: `rails new api --api -d postgresql`, enable Action Cable and pgvector, add gems `ruby_llm`, `neighbor`, `pdf-reader`, `json_schemer`, `mcp`, `rack-cors`, `rspec-rails`, `factory_bot_rails`
- [ ] `apps/web`: Vite React + TypeScript template, Tailwind, shadcn/ui init, TanStack Router + Query, Vite proxy for `/api` and `/cable`
- [ ] `packages/schemas` with rule and workflow schemas; `packages/api-types` generated by `json-schema-to-typescript`
- [ ] Generate all 16 models and migrations from section 4
- [ ] Write `Org::GraphSnapshot` and `Org::Resolver` with specs (including self-approval and no-manager cases)
- [ ] Write `Rules::Condition`, `Rules::Context`, `Rules::Engine`, `Rules::Explainer` with all 8 specs from section 5
- [ ] Seed script for Demo Factorial people (direct, not via CSV) so the graph is usable immediately

**Milestone:** `bundle exec rspec` is green and `rails runner` can evaluate a hand-written rule against a seeded person.

### Saturday morning (8 am – 1 pm, \~5 h): Assemble and the graph

- [ ] Create the messy CSV and the handbook PDF (section 16)
- [ ] `Assemble::CsvMapper` + graph builder with fuzzy manager matching and import issues
- [ ] Handbook chunking and embeddings
- [ ] `Assemble::PolicyExtractor` with quote verification and one retry on validation failure
- [ ] `AssembleJob` + `AssembleChannel` events
- [ ] Assemble page with live `OrgCanvas` (React Flow + dagre) and policy feed

**Milestone:** dropping both files builds the company live on screen.

### Saturday afternoon (2 pm – 8 pm, \~6 h): policies, runtime, agent

- [ ] Policies page: handbook pane, rule cards, hover-to-highlight, policy tester
- [ ] Ambiguity resolution with recompile and diff; publish gate
- [ ] `Workflows::Runtime` (start, act, override) + Inbox page + person switcher
- [ ] `Agent::Runner` with ask and act tools (`search_people`, `org_lookup`, `check_policy`, `search_handbook`, `who_approves`, `create_request`)
- [ ] `CommandBar` + `TraceDrawer` with live steps over `AgentChannel`

**Milestone:** Flows B and C work end to end.

### Saturday evening (9 pm – midnight, \~3 h): proposals and impact

- [ ] `ChangeProposal` model, `propose_org_change` tool
- [ ] `Impact::Analyzer` with rerouted, broken, self-approval and load changes, plus specs
- [ ] Proposal page: summary cards, org diff canvas, affected table, approve with re-check

**Milestone:** Flow D works, including the broken-chain catch.

### Sunday morning (8 am – 1 pm, \~5 h): workflows, conflicts, insights

- [ ] Workflow page with `FlowCanvas`, test run animation, and "describe a change" proposals
- [ ] `Rules::ConflictDetector` with probe generation and conflict list
- [ ] Seed 3 months of history
- [ ] `Impact::Backtester` for rule proposals
- [ ] Insights: interpreter, query builder with the 7 metrics, chart page with query chips

**Milestone:** "Who is overloaded with approvals?" returns a chart; a rule change shows flipped decisions.

### Sunday afternoon (2 pm – 6 pm, \~4 h): trust and MCP

- [ ] Eval fixtures (25 extraction, 15 agent, 10 insights)
- [ ] `Evals::Runner`, probe-based scoring, stability, judge; `EvalRunJob` + `EvalChannel`
- [ ] Write prompt v1 (weak) and v2 (strong); run both
- [ ] Trust page: scoreboard, compare, drill-down, candidate queue, promote
- [ ] MCP server with 4 tools and personal tokens; test from Claude Desktop

**Milestone:** Flow E works and Claude Desktop answers "Who approves my leave?"

### Sunday evening (7 pm – midnight, \~5 h): ship

- [ ] Deploy the API (Rails 8 Dockerfile) and the web app (static Vite build) to Coolify/Dokploy, with Postgres + pgvector and \`/api\` and \`/cable\` routed to the API
- [ ] Production seed and a "Reset demo" button that reloads Demo Factorial
- [ ] README and ADRs (section 18)
- [ ] Run all five flows on production; fix what breaks
- [ ] Record and edit the 3-minute video

**Milestone:** live URL, public repo, video link.

## 18. Deployment, README and demo video

The recruiter will judge Keel in this order: the video, the live link, the README, then the code. Spend the last evening making those three excellent rather than adding a feature.

### Deployment

Deploy the Rails 8 Dockerfile to your Coolify or Dokploy server with a Postgres 16 service that has the pgvector extension (the `pgvector/pgvector:pg16` image works). Run Solid Queue in the same container with `bin/jobs` or as a second service. Set `RUBY_LLM` provider keys as environment variables and put a monthly spending cap on the provider account.

Add a **demo guard**: rate-limit agent and assemble calls per IP (Rails 8 has `rate_limit` built in), and a "Reset demo" button that reloads Demo Factorial. Visitors will try things; the demo should survive them.

### README structure

1. **One-line pitch and video link** at the very top, then the live URL and demo login.
2. **What it does** in four short paragraphs: assemble, policies, agent and proposals, trust.
3. **Design principles** from section 2, in plain English.
4. **Architecture** diagram and the deterministic vs AI services split.
5. **How I evaluate it**: the three suites, behavioural scoring, stability, the feedback loop, and the actual numbers from your last run ("v2: 94% accuracy, 96% stability, $0.004 per case").
6. **Known limitations and what I would do next** with real customers: OAuth for MCP, multi-tenancy, per-customer eval sets, shadow mode for prompt changes, Spanish and Catalan handbooks.
7. **Running locally**: three commands.

The limitations section matters. It shows judgement, and the JD values engineers who "care about whether the thing they built actually worked".

### Architecture decision records

Add short files in `docs/decisions/`, each with context, decision, and consequences, in under 200 words:

- 001: The LLM compiles rules; a deterministic engine executes them
- 002: Workflows reference roles, resolved when each step becomes active
- 003: All AI writes go through Change Proposals
- 004: Score compiled rules by behaviour on probe requests, not by JSON equality
- 005: Insights uses typed query objects, never generated SQL
- 006: A pnpm monorepo with one shared JSON Schema package for Ruby and TypeScript

### The 3-minute video

Record at 1440p with a clean browser profile, dark mode, and the mouse cursor enlarged. Narrate in a calm, direct voice and cut dead time.

| Time | Show | Say (roughly) |
| --- | --- | --- |
| 0:00–0:15 | Empty Keel | "Every company already has a spreadsheet and a handbook. This is what happens when AI actually understands them." |
| 0:15–0:45 | Assemble running live | "Keel maps the messy columns, builds the org chart, and extracts policies, each linked to its source sentence." |
| 0:45–1:10 | Rule hover, ambiguity resolved | "It doesn't guess. Anything vague is flagged and has to be resolved before going live." |
| 1:10–1:50 | ⌘K reorg, impact preview, fix, approve | "The AI proposes; a person approves. Keel caught a broken approval chain before it happened." |
| 1:50–2:10 | Insights chart | "Ask questions in plain language. You can see exactly how Keel understood the question." |
| 2:10–2:40 | Trust page | "Every AI part is measured. Prompt v2 improved accuracy from 78% to 94%. Here's the case it still gets wrong." |
| 2:40–3:00 | Claude Desktop via MCP | "And other agents can use it too. Built in a weekend to show how I'd approach the operational core of Factorial's new product." |

### The application message

Keep it to four sentences: who you are, what you built and why it maps to the spinoff's focus, the video and live links, and one line on the evaluation numbers. Let the work carry the message.

## 19. Risks, mitigations and cut list

The biggest risk is scope: this plan is ambitious for one weekend, so decide now what you will cut and in what order. Three things are never cut: Assemble, Change Proposals with impact analysis, and the Trust page. Together they are the story.

### Risks

| Risk | Likelihood | Mitigation |
| --- | --- | --- |
| Running out of time | High | Follow the cut list below in order; stop adding features at 7 pm Sunday no matter what |
| LLM extraction is inconsistent on the handbook | Medium | Schema validation + one retry with errors; quote verification; a smaller, cleaner handbook if needed. Inconsistency also becomes eval material |
| Monorepo, proxy and Action Cable setup eats Friday | Medium | Keep the API on port 3000 and proxy `/api` and `/cable` through Vite, so dev has one origin and no CORS; use `concurrently` in the root `dev` script; timebox setup to 90 minutes |
| React Flow layout looks messy at 78 nodes | Medium | Use dagre top-down layout; collapse departments by default and expand on click |
| Live demo breaks during the recruiter's visit | Medium | Reset button, rate limits, spending cap, and the video as the primary artifact |
| MCP SDK API differs from the sketch | Low | Read the gem README first; MCP is a stretch item and can be shown with the MCP Inspector instead of Claude Desktop |
| API costs | Low | Cheap model for extraction and judging during development; total weekend cost should stay under about $20 |

### Cut list, in order

If you fall behind, cut from the top of this list first:

1. Spanish handbook
2. Natural-language workflow changes (keep seeded workflows and the test-run animation)
3. Conflict detection
4. Backtesting
5. Insights (keep the `approval_load` metric only, as a fixed chart on the Graph page)
6. MCP server
7. Agent eval suite (keep the extraction suite, which is the strongest one)

### Never cut

- **Assemble**: the opening shot and the proof that AI is central, not bolted on.
- **Change Proposals with impact analysis**: the human-oversight story and the best moment in the video.
- **Trust page with at least the extraction suite and v1 vs v2**: the direct answer to the JD's hardest requirement.
- **Engine and resolver tests**: they are what let you say "the part that makes decisions is fully tested" with a straight face.

### After the weekend

If you get to the interview stage, these make strong talking points about where you would take Keel next: running new prompts in **shadow mode** on live traffic before promotion, per-customer eval sets built from overrides, and a cost-versus-accuracy model router. Mention them as "what I would do with real customers", which fits how the spinoff plans to work with Factorial's 17,000 existing ones.
