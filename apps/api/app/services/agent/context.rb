module Agent
  # Who the agent is acting for (SPEC.md section 9: always the signed-in
  # person) and the run it's acting in, handed to every tool.
  Context = Data.define(:company, :person, :agent_run)
end
