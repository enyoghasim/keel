module Insights
  # The AI half of Insights (SPEC.md section 11, flow step 2): asks the LLM
  # to fill in an insight-query object for a natural-language question, or
  # to ask a clarifying question back when it's ambiguous. The output is
  # schema-validated (one retry) and handed to Insights::QueryBuilder; the
  # LLM never writes SQL and never sees a record — only the vocabulary it
  # may filter on (department names, expense categories in use).
  class Interpreter
    Result = Data.define(:query, :clarification)

    # Pass a block to learn what each ask cost (see Llm::StructuredAsk).
    def self.call(company:, question:, today: Date.current, &on_cost)
      schema = Llm::SchemaRegistry.fetch("insight-query")
      # strict: false — OpenAI's strict structured-output mode requires every
      # property to be listed in "required"; our schemas use ordinary
      # optional properties (group_by, filters, ..., and query/clarification
      # themselves), so strict mode 400s.
      chat = RubyLLM.chat.with_schema(schema.merge("strict" => false))

      data = Llm::StructuredAsk.call(chat: chat, schema: schema, prompt: prompt(company, question, today), &on_cost)
      # Without strict mode, the model sometimes fills in both query and
      # clarification (an empty clarification alongside a real query, or
      # vice versa) instead of omitting the one it didn't use. A present,
      # non-blank clarification always wins.
      clarification = data["clarification"].presence
      Result.new(query: clarification ? nil : data["query"], clarification: clarification)
    end

    def self.prompt(company, question, today)
      metrics = QueryBuilder::METRICS.map do |key, metric|
        "- #{key} (#{metric[:name]}, #{metric[:unit]}): group_by one of #{metric[:group_by].join(', ')}, or omit for a total"
      end

      <<~PROMPT
        You translate a question about a company's HR requests into an analytics query
        object. You never answer the question yourself — a deterministic query engine
        runs the object you produce.

        Today is #{today.iso8601} (#{quarter_example(today)}). Only set time_range when the
        question names or implies a period ("last quarter", "in August", "this year") — if it
        names no period at all, omit time_range entirely rather than defaulting to one; the
        query then covers all time. When you do resolve a relative date, use calendar quarters
        and months, not fiscal ones, unless asked. If the question could reasonably mean two
        different things (for example a fiscal vs calendar period, or two different metrics),
        return a short clarification instead of a query.

        Only set group_by when the question asks for a breakdown ("by department", "per
        person"); omit it for a single total, even if a breakdown would also be informative.
        Only set limit when the question asks for a top/bottom N; otherwise omit it so the
        engine returns everything (it must be between 1 and 50 — never set it above 50, and
        never set it just to be safe).

        When a filter value should match one of the department or category names below, copy
        it exactly as spelled there — these are case-sensitive, so "Travel" and "travel" are
        different values and only one of them is real.

        Metrics:
        #{metrics.join("\n")}

        Pick chart "line" for anything grouped by month, "pie" only for shares of a
        whole with few groups, "table" for a single total, and "bar" otherwise.

        Departments: #{company.departments.order(:name).pluck(:name).join(', ')}
        Expense categories: #{expense_categories(company).join(', ')}

        Question: #{question}
      PROMPT
    end

    def self.quarter_example(today)
      q = (today.month - 1) / 3 + 1
      last_q, year = q == 1 ? [ 4, today.year - 1 ] : [ q - 1, today.year ]
      start_month = (last_q - 1) * 3 + 1
      from = Date.new(year, start_month, 1)
      to = from.next_month(3) - 1
      "currently Q#{q}, so \"last quarter\" means #{from.iso8601}..#{to.iso8601}"
    end
    private_class_method :quarter_example
    private_class_method :prompt

    def self.expense_categories(company)
      company.requests.where(kind: "expense").distinct.pluck(Arel.sql("payload->>'category'")).compact.sort
    end
    private_class_method :expense_categories
  end
end
