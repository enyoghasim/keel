# Answers one /insights question (SPEC.md section 11): Insights::Interpreter
# turns it into a query object (the only LLM step), Insights::QueryBuilder
# runs it, and the outcome is recorded on the InsightQuery and broadcast on
# InsightChannel. Runs as a job because the Interpreter waits on a model.
class InsightJob < ApplicationJob
  UNINTERPRETABLE = "Keel couldn't turn that question into a query it can run. " \
                    "Try rephrasing it, or start from one of the suggested questions.".freeze
  UNEXPECTED = "Something went wrong answering that question. Please try again.".freeze

  def perform(insight_query_id)
    insight_query = InsightQuery.find(insight_query_id)
    return unless insight_query.status == "pending"

    answer(insight_query)
    InsightChannel.broadcast_to(insight_query, insight_query.as_payload)
  end

  private

  def answer(insight_query)
    interpretation = Insights::Interpreter.call(company: insight_query.company, question: insight_query.question)
    insight_query.model = RubyLLM.config.default_model

    if interpretation.clarification
      insight_query.update!(status: "needs_clarification", clarification: interpretation.clarification)
    else
      insight_query.query = interpretation.query
      result = Insights::QueryBuilder.call(company: insight_query.company, query: interpretation.query)
      insight_query.update!(status: "answered", result: { "rows" => result.rows.map(&:to_h), "unit" => result.unit, "summary" => result.summary })
    end
  rescue Insights::QueryBuilder::InvalidQuery => e
    insight_query.update!(status: "failed", error_message: e.message)
  rescue Llm::StructuredAsk::ValidationError => e
    Rails.logger.warn("[InsightJob] interpreter output failed validation twice: #{e.message}")
    insight_query.update!(status: "failed", error_message: UNINTERPRETABLE)
  rescue StandardError => e
    Rails.logger.error("[InsightJob] #{e.class}: #{e.message}")
    insight_query.update!(status: "failed", error_message: UNEXPECTED)
  end
end
