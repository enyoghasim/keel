# packages/schemas & packages/api-types — Agent Guide

`packages/schemas/schemas/*.schema.json` is the single source of truth for every shape an LLM is allowed to produce (rule, workflow, insight-query, csv-mapping, change-proposal — SPEC.md section 4). Both sides of the app follow it, never the other way around:

- **Ruby** (`apps/api`) loads every schema at boot via `Llm::SchemaRegistry` and validates LLM output against it with `json_schemer` before anything is saved.
- **TypeScript** (`apps/web`, via the `api-types` package) gets its types generated from the same files with `json-schema-to-typescript`.

## Workflow

1. Add or edit a `*.schema.json` file in `packages/schemas/schemas/`.
2. Run `pnpm gen:types` at the repo root — this regenerates `packages/api-types/src/generated/*.ts` (gitignored; it's build output, not source).
3. Both the Rails validation and the TypeScript types now agree. A CI step should fail if the generated types are stale relative to the schema files — don't hand-edit anything under `src/generated/`.

## Why this exists

Comparing a schema change's downstream effect in Ruby vs. TypeScript separately is how the two sides drift. One file, one regeneration step, both sides follow — that's the whole reason the monorepo is worth it (SPEC.md section 3).

Keep fields and enums in schemas as a fixed whitelist (e.g. the operators a rule condition may use) rather than open strings — the LLM should not be able to invent a field or operator the deterministic engine doesn't understand.
