module Agent
  # The plain-English paragraph on the proposal page (SPEC.md section 10),
  # written by the LLM from the computed impact only. #facts boils the
  # stored impact down to counts and names — the only thing the model sees,
  # never the diff or the people table — and #call refuses a paragraph that
  # states a number the facts don't contain, so the model can describe the
  # effects Keel computed but not invent one (AGENTS.md rule 2). Nothing is
  # decided here: the paragraph is a reading aid next to the numbers.
  class ProposalExplainer
    class Unfaithful < StandardError; end

    EXAMPLE_LIMIT = 5

    def self.call(proposal)
      facts = facts(proposal)
      schema = Llm::SchemaRegistry.fetch("proposal-explanation")
      text = Llm::StructuredAsk.call(chat: RubyLLM.chat.with_schema(schema), schema: schema, prompt: prompt(facts)).fetch("explanation")

      invented = numbers(text) - numbers(facts.to_json)
      raise Unfaithful, "the explanation states #{invented.join(', ')}, which the impact doesn't contain" if invented.any?

      text
    end

    def self.facts(proposal)
      case proposal.kind
      when "org" then org_facts(proposal)
      when "rule" then rule_facts(proposal)
      else workflow_facts(proposal)
      end
    end

    def self.org_facts(proposal)
      impact = proposal.impact
      names = proposal.company.people.where(id: person_ids(impact)).pluck(:id, :name).to_h
      name = ->(id) { names.fetch(id, "someone") }

      {
        "kind" => "org", "title" => proposal.title,
        "rerouted_count" => impact["rerouted"].size,
        "rerouted_examples" => impact["rerouted"].uniq { _1["person_id"] }.first(EXAMPLE_LIMIT).map do |row|
          { "person" => name.(row["person_id"]), "before" => row["before"]["approvers"].map(&name), "after" => row["after"]["approvers"].map(&name) }
        end,
        "broken_count" => impact["broken"].size,
        "broken_examples" => impact["broken"].uniq { _1["person_id"] }.first(EXAMPLE_LIMIT).map { { "person" => name.(_1["person_id"]), "problems" => _1["after"]["errors"] } },
        "self_approval_count" => impact["self_approval"].size,
        "approval_load_changes" => impact["approval_load_changes"].max_by(EXAMPLE_LIMIT) { (_1["after"] - _1["before"]).abs }
          .map { { "approver" => name.(_1["approver_id"]), "before" => _1["before"], "after" => _1["after"] } },
        "open_requests_rerouted" => impact["rerouted_in_flight"].size
      }
    end
    private_class_method :org_facts

    def self.person_ids(impact)
      impact.values_at("rerouted", "broken", "self_approval").flatten.flat_map { [ _1["person_id"], *_1["before"]["approvers"], *_1["after"]["approvers"] ] } |
        impact["approval_load_changes"].pluck("approver_id")
    end
    private_class_method :person_ids

    def self.rule_facts(proposal)
      backtest = proposal.impact["backtest"]

      {
        "kind" => "rule", "title" => proposal.title, "past_requests_replayed" => backtest["total"], "decisions_flipped" => backtest["flipped_count"],
        "summary" => backtest["summary"], "new_conflicts" => backtest["new_conflicts"].pluck("warning")
      }
    end
    private_class_method :rule_facts

    def self.workflow_facts(proposal)
      impact = proposal.impact

      {
        "kind" => "workflow", "title" => proposal.title,
        "steps_added" => impact["steps"]["added"], "steps_removed" => impact["steps"]["removed"],
        "steps_changed" => impact["steps"]["changed"], "steps_moved" => impact["steps"]["moved"],
        "people_affected" => impact["affected_count"],
        "broken_steps" => impact["broken"].map { { "step" => _1["step_key"], "reference" => _1["reference"], "people" => _1["person_count"] } },
        "open_requests_on_removed_steps" => impact["in_flight"]
      }
    end
    private_class_method :workflow_facts

    # "1,200" and "1200" are the same number.
    def self.numbers(text) = text.gsub(/(?<=\d),(?=\d{3})/, "").scan(/\d+/).uniq
    private_class_method :numbers

    def self.prompt(facts)
      <<~PROMPT
        You explain a proposed change to a company's organisation, policies or workflows to an HR
        manager who is not technical. Below are the computed facts about what the change would do,
        as JSON. Write one short paragraph (at most four sentences, no markdown, no bullet points)
        saying in plain English what it would mean and whether anything needs attention first.

        Use only the facts below. Do not state any number, name or effect that is not in them, do
        not guess at causes, and do not say the change has happened: it is only a proposal waiting
        for a person to approve it.

        Facts:
        #{JSON.pretty_generate(facts)}
      PROMPT
    end
    private_class_method :prompt
  end
end
