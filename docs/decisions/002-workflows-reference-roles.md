# 002: Workflows reference roles, resolved when each step becomes active

**Status:** accepted

## Context
People change jobs; an approval chain that stores "Tunde approves" is wrong the day Tunde moves. Names and ids stored in policies and workflows go stale silently.

## Decision
Policies and workflows hold references (`manager_of(requester)`, `role:finance_lead`, `head_of(requester.department)`). `Org::Resolver` resolves them against the company graph at the moment a step becomes active, never at definition time. A reference that resolves to nobody, or to the requester themselves, is reported rather than skipped.

## Consequences
- A reorg changes who approves without editing a single workflow.
- Impact analysis can ask "what would resolve differently?" by resolving against a modified snapshot.
- In-flight steps are re-resolved when the graph changes, which needs care (the analyzer reports rerouted in-flight steps).
- A graph with holes (nobody holds a role) breaks chains; Keel surfaces those before approval.
