require "rails_helper"

RSpec.describe ReapStaleWorkJob, type: :job do
  it "runs the reaper" do
    allow(StaleWork::Reaper).to receive(:call)

    described_class.perform_now

    expect(StaleWork::Reaper).to have_received(:call)
  end
end
