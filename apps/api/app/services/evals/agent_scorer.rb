module Evals
  # The deterministic half of scoring an agent eval case (SPEC.md section
  # 12): tool selection and outcome, read off the recorded tool calls — never
  # the model's wording, which Evals::Judge grades separately. An expected
  # case lists `tools` that must be called, optional `forbidden_tools` (an
  # Ask must not call create_request), and `outputs`: fields the last call
  # of a tool must contain, matched as a subset so incidental fields don't
  # fail a case.
  class AgentScorer
    Result = Data.define(:passed, :diff)

    def self.call(expected:, tool_calls:)
      called = tool_calls.pluck("name")
      diff = []

      Array(expected["tools"]).each do |tool|
        diff << { "field" => "tools", "expected" => tool, "actual" => called.uniq } unless called.include?(tool)
      end
      Array(expected["forbidden_tools"]).each do |tool|
        diff << { "field" => "forbidden_tools", "expected" => "not #{tool}", "actual" => tool } if called.include?(tool)
      end
      (expected["outputs"] || {}).each do |tool, fields|
        last = tool_calls.reverse.find { _1["name"] == tool }
        next unless last # already reported as a missing tool

        subset_diff(fields, last["output"], "outputs.#{tool}", diff)
      end

      Result.new(diff.empty?, diff)
    end

    def self.subset_diff(expected, actual, path, diff)
      case expected
      when Hash
        expected.each { |key, value| subset_diff(value, actual.is_a?(Hash) ? actual[key] : nil, "#{path}.#{key}", diff) }
      when Array
        expected.each_with_index do |value, i|
          match = Array(actual).any? { |candidate| subset_diff(value, candidate, path, []).empty? }
          diff << { "field" => "#{path}[#{i}]", "expected" => value, "actual" => actual } unless match
        end
      else
        diff << { "field" => path, "expected" => expected, "actual" => actual } unless expected == actual
      end
      diff
    end
    private_class_method :subset_diff
  end
end
