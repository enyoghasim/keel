# 005: Insights uses typed query objects, never generated SQL

**Status:** accepted

## Context
Natural-language analytics invites "have the model write SQL". That means model-authored text running against production data: injection, wrong joins that look right, and no way to show a person how their question was understood.

## Decision
`Insights::Interpreter` only translates a question into a small query object validated by the `insight-query` schema (metric, filters, grouping, date range). It sees the vocabulary it may filter on (department names, expense categories), never the records. `Insights::QueryBuilder` is the only code that computes an answer, from fixed ActiveRecord queries. The page shows the interpreted query beside the result.

## Consequences
- The model cannot read or write data; the worst case is a wrong but visible interpretation.
- Anything outside the supported metrics is refused with a clarification, not improvised.
- New kinds of question need a schema and builder change, which is slower and safer.
