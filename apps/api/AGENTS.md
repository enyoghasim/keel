# apps/api — Agent Guide

Rails 8 API. Read [docs/SPEC.md](../../docs/SPEC.md) sections 3–13 before building a service for the first time — this file is conventions, not the design.

## TDD

Write the RSpec example before the implementation. This is non-negotiable for anything under `app/services/` — especially the deterministic ones (`Org::Resolver`, `Rules::Engine`, `Impact::Analyzer`, `Rules::ConflictDetector`). SPEC.md section 5 has a worked test plan: one example per real-world scenario (e.g. "Requester is the finance lead, €2,500 → blocked, self-approval"), not one per method.

- `bundle exec rspec` must be green before a commit.
- FactoryBot is wired into `rails_helper.rb` (`config.include FactoryBot::Syntax::Methods`) — use factories, not fixtures, for new specs.
- `bundle exec rubocop` runs on staged `.rb` files via lint-staged; fix offenses rather than disabling cops.

## Deterministic vs AI services

`app/services/` is split into two families (SPEC.md section 3) — keep new code on the correct side of the line:

- **Deterministic** (`org/`, `rules/`, `workflows/`, `impact/`, `insights/query_builder.rb`): no LLM calls, 100% unit-tested, pure Ruby. These make every decision.
- **AI** (`assemble/`, `agent/`, `evals/`, `insights/interpreter.rb`): call the LLM via `ruby_llm`, validate output against a `packages/schemas` schema with `json_schemer`, then hand structured data to the deterministic side. An AI service never decides an outcome itself.

`insights/` is the one folder that holds both families, per SPEC.md section 3's tree: `Insights::Interpreter` (AI) only turns a question into a schema-validated query object, and `Insights::QueryBuilder` (deterministic) is the only thing that computes an answer from the database. Keep it that way — `interpreter.rb` reads only the vocabulary the LLM may filter on (department names, expense categories), never the records an answer is computed from, and nothing in `query_builder.rb` calls the LLM.

Controllers stay thin: validate input, enqueue a job or call a service, render. Anything that touches an LLM runs in a Solid Queue job — web requests never wait on a model.

## References, not names

Rules and workflows store reference strings (`manager_of(requester)`, `role:finance_lead`), resolved through `Org::Resolver` against an `Org::GraphSnapshot`. Never store or pass a person's name or ID where a reference belongs — see AGENTS.md at the repo root, rule 1.

## Schemas

Every LLM output is validated against a JSON Schema from `packages/schemas/schemas/*.schema.json` before it's saved, loaded at boot via `Llm::SchemaRegistry`. Add or change a schema there, not ad hoc in Ruby — `pnpm gen:types` regenerates the TypeScript side from the same file.

## Local setup

Gems install to a local `vendor/bundle` (see `.bundle/config`) rather than the global gem path — just run `bundle install`, no flags needed. `config/database.yml` reads connection settings from `DATABASE_HOST`/`PORT`/`USERNAME`/`PASSWORD` env vars (see `.env.example`), so it works identically bare-metal and in `docker-compose`.
