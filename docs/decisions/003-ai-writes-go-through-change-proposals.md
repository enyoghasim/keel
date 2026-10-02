# 003: All AI writes go through Change Proposals

**Status:** accepted

## Context
The agent can be asked to reorganise the org or change a policy. An assistant that edits company data directly is one bad answer away from an incident, and nobody can review what it did.

## Decision
The AI proposes, a human approves, a deterministic engine executes. Every AI-originated write (org, rule or workflow change) is stored as a `ChangeProposal` with a computed impact report (`Impact::Analyzer`), and nothing applies until an `hr_admin` approves it. Proposals that would break an approval chain or create a rule conflict need an explicit "approve anyway" with a reason, and a stale diff is refused.

## Consequences
- The model never holds write access; its tools only record proposals.
- Impact numbers come from the engine, not from the model's description of them.
- Each proposal keeps a link to the agent trace that produced it.
- There is a human in every loop, so throughput is bounded by reviewers.
