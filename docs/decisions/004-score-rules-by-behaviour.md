# 004: Score compiled rules by behaviour on probe requests, not by JSON equality

**Status:** accepted

## Context
To improve the extraction prompt we need a score. Two rules can be written differently (`lte 1000` versus `lt 1001`, reordered conditions) and mean exactly the same thing; JSON equality would call that a failure.

## Decision
Evals compile a passage and run the compiled and the expected rules against the same generated probe requests (boundary values and categorical values, via the conflict detector's probe generator). A case passes when the decisions agree on every probe. Verbatim-quote and ambiguity checks are scored separately, and stability is measured by compiling several times.

## Consequences
- Equivalent rules pass; a wrong threshold (`lt` for `lte`) fails visibly on the boundary probe.
- Probe quality bounds score quality: a missed condition outside the probed values goes unnoticed.
- Scores are comparable across prompt versions, which is what makes "promote v2" defensible.
