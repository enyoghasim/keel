require "rails_helper"

RSpec.describe RuleResolutionJob, type: :job do
  include ActionCable::TestHelper

  # Assemble::AmbiguityResolver has its own spec; this job runs it off the
  # request thread, records the outcome on the RuleResolution and broadcasts it.
  let(:resolution) { create(:rule_resolution) }
  let(:new_rule) { create(:rule, policy: resolution.rule.policy, key: resolution.rule.key, status: "resolved") }

  def resolves
    allow(Assemble::AmbiguityResolver).to receive(:call)
      .and_return(Assemble::AmbiguityResolver::Result.new(before: resolution.rule, after: new_rule))
  end

  it "records the new rule version and the model that wrote it" do
    resolves

    described_class.perform_now(resolution.id)

    expect(resolution.reload).to have_attributes(status: "resolved", new_rule: new_rule, model: RubyLLM.config.default_model)
    expect(Assemble::AmbiguityResolver).to have_received(:call)
      .with(rule: resolution.rule, ambiguity_index: 0, answer: "A")
  end

  it "broadcasts the outcome with both versions" do
    resolves

    expect { described_class.perform_now(resolution.id) }.to have_broadcasted_to(resolution).from_channel(RuleResolutionChannel)
      .with(hash_including("status" => "resolved", "after" => hash_including("id" => new_rule.id)))
  end

  it "fails with a plain message when the model's rewrite is invalid, leaving the rule alone" do
    allow(Assemble::AmbiguityResolver).to receive(:call).and_raise(Assemble::AmbiguityResolver::InvalidRewrite, "key")

    described_class.perform_now(resolution.id)

    expect(resolution.reload).to have_attributes(status: "failed", error_message: RuleResolutionJob::INVALID)
    expect(resolution.rule.reload.status).to eq("extracted")
  end

  it "fails with a plain message when the model can't be reached, not with the raw error" do
    allow(Assemble::AmbiguityResolver).to receive(:call).and_raise(RubyLLM::ConfigurationError, "Missing configuration for OpenAI: openai_api_key")

    described_class.perform_now(resolution.id)

    expect(resolution.reload.error_message).to eq(RuleResolutionJob::UNEXPECTED)
  end

  it "does nothing for a resolution that already finished" do
    resolution.update!(status: "resolved")
    allow(Assemble::AmbiguityResolver).to receive(:call)

    described_class.perform_now(resolution.id)

    expect(Assemble::AmbiguityResolver).not_to have_received(:call)
  end
end
