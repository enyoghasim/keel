require "rails_helper"

RSpec.describe ProposalExplanationJob, type: :job do
  include ActionCable::TestHelper

  # Agent::ProposalExplainer has its own spec; this job runs it off the
  # request thread, saves the paragraph on the proposal and tells the open
  # Proposals page. The explainer (the LLM) is stubbed.
  let(:company) { create(:company) }
  let(:proposal) { create(:change_proposal, company: company) }

  it "saves the explanation and broadcasts the proposal to its company" do
    allow(Agent::ProposalExplainer).to receive(:call).with(proposal).and_return("Ada gets more approvals.")

    expect { described_class.perform_now(proposal.id) }.to have_broadcasted_to(company).from_channel(ChangeProposalChannel)
      .with(hash_including("id" => proposal.id, "explanation" => "Ada gets more approvals."))

    expect(proposal.reload.explanation).to eq("Ada gets more approvals.")
  end

  it "leaves the proposal without an explanation when the model's paragraph is unfaithful, rather than showing it" do
    allow(Agent::ProposalExplainer).to receive(:call).and_raise(Agent::ProposalExplainer::Unfaithful, "states 40")

    expect { described_class.perform_now(proposal.id) }.not_to raise_error

    expect(proposal.reload.explanation).to be_nil
  end

  it "leaves it blank too when the model fails validation or errors" do
    allow(Agent::ProposalExplainer).to receive(:call).and_raise(Llm::StructuredAsk::ValidationError, "bad")
    described_class.perform_now(proposal.id)
    allow(Agent::ProposalExplainer).to receive(:call).and_raise("boom")
    described_class.perform_now(proposal.id)

    expect(proposal.reload.explanation).to be_nil
  end

  it "doesn't redo an explanation it already has" do
    proposal.update!(explanation: "Already explained.")
    allow(Agent::ProposalExplainer).to receive(:call)

    described_class.perform_now(proposal.id)

    expect(Agent::ProposalExplainer).not_to have_received(:call)
  end
end
