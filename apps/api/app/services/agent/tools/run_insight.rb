module Agent
  module Tools
    # Hands an analytics question to Insights (SPEC.md section 11) and
    # returns the interpreted query and its rows. Recorded as an
    # InsightQuery like any question asked on /insights, so it has the same
    # trace and shows in the person's recent questions.
    class RunInsight < Base
      ROW_LIMIT = 10

      tool_name "run_insight"
      description "Answer an analytics question about requests, leave days, expenses, approval load, time to " \
                  "decision, override rate or auto-approval rate, e.g. 'leave days by department last quarter'. " \
                  "Returns how the question was interpreted, the computed rows and a one-line summary, or a " \
                  "clarifying question to pass back to the person."
      params({
        type: "object", additionalProperties: false, required: [ "question" ],
        properties: { question: { type: "string", description: "The analytics question in plain language" } }
      })

      def execute(question:)
        insight_query = company.insight_queries.create!(person: person, question: question)
        InsightJob.perform_now(insight_query.id)
        insight_query.reload

        {
          "insight_query_id" => insight_query.id, "status" => insight_query.status, "query" => insight_query.query,
          "clarification" => insight_query.clarification, "error" => insight_query.error_message,
          "summary" => insight_query.result&.dig("summary"), "unit" => insight_query.result&.dig("unit"),
          "rows" => insight_query.result&.dig("rows")&.first(ROW_LIMIT)
        }.compact
      end
    end
  end
end
