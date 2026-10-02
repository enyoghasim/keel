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
      chat = RubyLLM.chat.with_schema(schema)

      data = Llm::StructuredAsk.call(chat: chat, schema: schema, prompt: prompt(company, question, today), &on_cost)
      Result.new(query: data["query"], clarification: data["clarification"])
    end

    def self.prompt(company, question, today)
      metrics = QueryBuilder::METRICS.map do |key, metric|
        "- #{key} (#{metric[:name]}, #{metric[:unit]}): group_by one of #{metric[:group_by].join(', ')}, or omit for a total"
      end

      <<~PROMPT
        You translate a question about a company's HR requests into an analytics query
        object. You never answer the question yourself — a deterministic query engine
        runs the object you produce.

        Today is #{today.iso8601}. Resolve relative dates ("last quarter", "this month")
        into an explicit time_range using calendar quarters and months. If the question
        could reasonably mean two different things (for example a fiscal vs calendar
        period, or two different metrics), return a short clarification instead of a query.

        Metrics:
        #{metrics.join("\n")}

        Pick chart "line" for anything grouped by month, "pie" only for shares of a
        whole with few groups, "table" for a single total, and "bar" otherwise.

        Departments: #{company.departments.order(:name).pluck(:name).join(', ')}
        Expense categories: #{expense_categories(company).join(', ')}

        Question: #{question}
      PROMPT
    end
    private_class_method :prompt

    def self.expense_categories(company)
      company.requests.where(kind: "expense").distinct.pluck(Arel.sql("payload->>'category'")).compact.sort
    end
    private_class_method :expense_categories
  end
end
