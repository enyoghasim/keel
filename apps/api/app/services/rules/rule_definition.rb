module Rules
  # A single executable rule: a condition tree plus an action. Plain rather
  # than ActiveRecord-backed — the `rules`/`policies` tables don't exist yet
  # (that's the assemble/policy-extraction work); the engine only needs
  # these four fields regardless of what eventually constructs them.
  RuleDefinition = Data.define(:key, :priority, :conditions, :actions)
end
