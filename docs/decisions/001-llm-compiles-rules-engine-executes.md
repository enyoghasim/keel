# 001: The LLM compiles rules; a deterministic engine executes them

**Status:** accepted

## Context
Company policy lives in a handbook written in prose. A model can read it, but a model that also *decides* each request would be unpredictable, untestable, and impossible to audit.

## Decision
The LLM runs once, at compile time: it turns handbook text into structured rules (`policy-rules` schema, closed whitelists of fields and operators), each carrying a verbatim `source_quote` that Ruby checks against the handbook. `Rules::Engine` then evaluates requests deterministically from those rules. Anything vague becomes an `ambiguity` a person must answer, never a guess.

## Consequences
- The part that makes decisions is pure Ruby and fully unit-tested.
- Every outcome traces back to a rule and its handbook quote.
- Compilation quality is the risk, so it is measured (see 004) rather than trusted.
- Policies can't express anything outside the whitelisted vocabulary without a schema change.
