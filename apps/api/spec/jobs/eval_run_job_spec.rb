require "rails_helper"

RSpec.describe EvalRunJob, type: :job do
  include ActionCable::TestHelper

  # Evals::Runner has its own spec; this job runs it and broadcasts
  # progress on EvalChannel. The Interpreter (the LLM) is stubbed.
  let(:company) { create(:company) }
  let(:eval_run) { create(:eval_run, company: company) }
  let(:query) { { "metric" => "request_count", "chart" => "table" } }

  before do
    create(:eval_case, key: "count", input: { "question" => "How many requests?", "today" => "2026-10-02" }, expected: { "query" => query })
    allow(Insights::Interpreter).to receive(:call).and_return(Insights::Interpreter::Result.new(query: query, clarification: nil))
  end

  it "runs the suite and broadcasts each case's result, then the finished run" do
    expect { described_class.perform_now(eval_run.id) }
      .to have_broadcasted_to(eval_run).from_channel(EvalChannel)
      .with(hash_including("event" => "result", "done" => 1, "total" => 1, "result" => hash_including("case_key" => "count", "passed" => true)))
      .and have_broadcasted_to(eval_run).from_channel(EvalChannel)
      .with(hash_including("event" => "run", "run" => hash_including("status" => "completed", "accuracy" => 1.0)))
  end

  it "marks the run failed, rather than leaving it running forever, when something unexpected breaks" do
    allow(Insights::Interpreter).to receive(:call).and_raise(Faraday::ConnectionFailed, "connection refused")

    described_class.perform_now(eval_run.id)

    expect(eval_run.reload).to have_attributes(status: "failed", error_message: "Faraday::ConnectionFailed: connection refused")
  end

  it "doesn't re-run a run that has already finished" do
    eval_run.update!(status: "completed")

    described_class.perform_now(eval_run.id)

    expect(Insights::Interpreter).not_to have_received(:call)
  end
end
