# 006: A pnpm monorepo with one shared JSON Schema package for Ruby and TypeScript

**Status:** accepted

## Context
Rails validates what the LLM returns; the React app renders it. Two hand-maintained copies of "what a rule looks like" drift apart, and the drift shows up as runtime bugs between the two.

## Decision
`packages/schemas` holds the JSON Schemas. Ruby loads them at boot (`Llm::SchemaRegistry`) and validates every LLM output with `json_schemer`; `packages/api-types` generates TypeScript from the same files (`pnpm gen:types`), alongside hand-written types for plain API shapes. API, web and schemas live in one repository.

## Consequences
- One schema change updates validation and types together.
- Generated types are gitignored, so `pnpm gen:types` must run after a schema change (not yet automated).
- One repo means one PR can change contract, backend and UI, at the cost of a heavier checkout.
