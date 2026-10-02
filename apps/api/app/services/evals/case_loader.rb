module Evals
  # Loads hand-written eval cases from a fixtures/evals/*.yml file into
  # eval_cases, upserting by key so reloading picks up edits. A case's
  # status is left alone on reload: once a reviewer archives a case, the
  # fixture file doesn't bring it back.
  class CaseLoader
    FIXTURES_DIR = Rails.root.join("..", "..", "fixtures", "evals")

    def self.call(suite:, path: FIXTURES_DIR.join("#{suite}.yml"))
      YAML.safe_load_file(path).map do |data|
        data = JSON.parse(data.to_json) # string keys all the way down, like a jsonb round trip
        eval_case = EvalCase.find_or_initialize_by(suite: suite, key: data.fetch("key"))
        eval_case.update!(input: data.fetch("input"), expected: data.fetch("expected"), notes: data["notes"], source: "manual")
        eval_case
      end
    end
  end
end
