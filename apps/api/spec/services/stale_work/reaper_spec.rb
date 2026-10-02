require "rails_helper"

RSpec.describe StaleWork::Reaper do
  include ActionCable::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  # A worker that dies mid-job leaves its record pending or running forever
  # (the jobs skip anything not pending, and nothing retries). The reaper
  # is the deterministic backstop: no LLM, just a clock and a status.
  def stale(factory, status, age, **attrs)
    create(factory, status: status, **attrs).tap { |record| record.update_columns(updated_at: age.ago) }
  end

  it "fails agent runs stuck running or pending past the timeout, telling the person what happened, and broadcasts the change" do
    running = stale(:agent_run, "running", 6.minutes)
    pending = stale(:agent_run, "pending", 6.minutes)

    expect { described_class.call }.to have_broadcasted_to(running).from_channel(AgentChannel)
      .with(hash_including("event" => "run", "run" => hash_including("status" => "failed", "error_message" => described_class::MESSAGE)))

    expect([ running, pending ].map { _1.reload.status }).to eq(%w[failed failed])
    expect(pending.error_message).to eq(described_class::MESSAGE)
  end

  it "fails stuck insight questions and eval runs the same way, stamping the eval run's finish time" do
    insight = stale(:insight_query, "pending", 3.minutes)
    eval_run = stale(:eval_run, "running", 16.minutes)

    expect { described_class.call }.to have_broadcasted_to(insight).from_channel(InsightChannel)
      .and have_broadcasted_to(eval_run).from_channel(EvalChannel)

    expect(insight.reload).to have_attributes(status: "failed", error_message: described_class::MESSAGE)
    expect(eval_run.reload).to have_attributes(status: "failed", error_message: described_class::MESSAGE)
    expect(eval_run.finished_at).to be_within(5.seconds).of(Time.current)
  end

  it "leaves recent work and finished work alone" do
    recent = stale(:agent_run, "running", 2.minutes)
    done = stale(:agent_run, "completed", 1.day, final_text: "Done.")
    long_eval = stale(:eval_run, "running", 10.minutes)

    expect(described_class.call).to eq(agent_runs: 0, insight_queries: 0, eval_runs: 0)

    expect(recent.reload.status).to eq("running")
    expect(done.reload.status).to eq("completed")
    expect(long_eval.reload.status).to eq("running")
  end

  it "reports how many of each it failed, measured against the clock it's given" do
    create(:agent_run)
    create(:insight_query)

    travel_to(1.hour.from_now) do
      expect(described_class.call).to eq(agent_runs: 1, insight_queries: 1, eval_runs: 0)
    end
  end
end
