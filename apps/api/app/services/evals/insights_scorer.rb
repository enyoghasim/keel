module Evals
  # Scores one insights eval case (SPEC.md section 12): compares the
  # interpretation Insights::Interpreter produced against the expected one,
  # field by field on what was asked — metric, group_by, filters, time
  # range. No LLM; the scorer is deterministic so a score can be trusted.
  # A case can instead expect a clarifying question ({"clarification" =>
  # true}), in which case any clarification passes and any guess fails.
  class InsightsScorer
    Check = Data.define(:field, :expected, :actual, :match)
    Result = Data.define(:passed, :checks) do
      def diff = checks.reject(&:match).map { { "field" => _1.field, "expected" => _1.expected, "actual" => _1.actual } }
    end

    SCORED_FIELDS = %w[metric group_by filters time_range].freeze

    def self.call(expected:, actual:)
      expected_query = expected["query"]
      actual_query = actual["query"]

      checks =
        if expected_query.nil?
          [ Check.new("clarification", true, actual_query || actual["clarification"], actual_query.nil?) ]
        elsif actual_query.nil?
          [ Check.new("query", expected_query, actual["clarification"], false) ]
        else
          SCORED_FIELDS.map do |field|
            Check.new(field, expected_query[field], actual_query[field], normalize(field, expected_query[field]) == normalize(field, actual_query[field]))
          end
        end

      Result.new(passed: checks.all?(&:match), checks: checks)
    end

    # Filters are a set, and eq on one value means the same as in on it.
    def self.normalize(field, value)
      return value unless field == "filters"

      Array(value).map do |filter|
        values = Array(filter["value"]).sort
        op = filter["op"] == "neq" ? "neq" : "in"
        [ filter["field"], op, values ]
      end.sort
    end
    private_class_method :normalize
  end
end
