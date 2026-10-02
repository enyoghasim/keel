module Rules
  class Condition
    OPERATORS = {
      "eq" => ->(a, b) { a == b },
      "neq" => ->(a, b) { a != b },
      "gt" => ->(a, b) { a > b },
      "gte" => ->(a, b) { a >= b },
      "lt" => ->(a, b) { a < b },
      "lte" => ->(a, b) { a <= b },
      "in" => ->(a, b) { b.include?(a) },
      "not_in" => ->(a, b) { !b.include?(a) },
      "between" => ->(a, b) { a.between?(b[0], b[1]) }
    }.freeze

    ORDERING = %w[gt gte lt lte between].freeze

    def self.match?(node, ctx)
      return node["all"].all? { match?(_1, ctx) } if node["all"]
      return node["any"].any? { match?(_1, ctx) } if node["any"]

      operator = OPERATORS.fetch(node["op"]) { raise ArgumentError, "unknown operator #{node["op"]}" }
      actual = ctx[node["field"]]
      # A request that doesn't carry the field can't satisfy an ordering
      # comparison (e.g. a leave request with no notice_days vs "< 14").
      return false if actual.nil? && ORDERING.include?(node["op"])

      operator.call(actual, node["value"])
    end
  end
end
