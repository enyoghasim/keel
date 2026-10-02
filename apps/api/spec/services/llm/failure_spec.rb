require "rails_helper"

RSpec.describe Llm::Failure do
  # A visitor who hits an AI feature on a deployment with no model key should
  # read what to do about it, not RubyLLM::ConfigurationError.
  it "explains a missing model key in plain words" do
    error = RubyLLM::ConfigurationError.new("Missing configuration for OpenAI: openai_api_key")

    message = described_class.message_for(error, fallback: "Something went wrong.")

    expect(message).to eq(Llm::Failure::NO_MODEL)
    expect(message).not_to include("RubyLLM", "ConfigurationError")
  end

  it "uses the caller's fallback for any other error" do
    expect(described_class.message_for(RuntimeError.new("boom"), fallback: "Something went wrong.")).to eq("Something went wrong.")
  end
end
