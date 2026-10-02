require "rails_helper"

RSpec.describe EvalChannel, type: :channel do
  it "streams one eval run's progress and sends its current state straight away" do
    eval_run = create(:eval_run, status: "running", cases_count: 11)

    subscribe(eval_run_id: eval_run.id)

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(eval_run)
    expect(transmissions.last).to include("event" => "run", "run" => include("id" => eval_run.id, "status" => "running"))
  end
end
