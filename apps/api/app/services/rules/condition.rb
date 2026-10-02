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

    def self.match?(node, ctx)
      return node["all"].all? { match?(_1, ctx) } if node["all"]
      return node["any"].any? { match?(_1, ctx) } if node["any"]

      operator = OPERATORS.fetch(node["op"]) { raise ArgumentError, "unknown operator #{node["op"]}" }
      operator.call(ctx[node["field"]], node["value"])
    end
  end
end
