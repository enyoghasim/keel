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

  # The provider's own error is the one thing that says what to fix, so it is shown, not hidden.
  {
    RubyLLM::UnauthorizedError => /rejected the API key/,
    RubyLLM::ForbiddenError => /rejected the API key/,
    RubyLLM::PaymentRequiredError => /credit|billing|quota/i,
    RubyLLM::RateLimitError => /rate limit|quota/i,
    RubyLLM::BadRequestError => /refused the request/
  }.each do |error_class, expected|
    it "names the provider's #{error_class.name.demodulize} and passes on what it said" do
      message = described_class.message_for(error_class.new(nil, "The model `gpt-5.1` does not exist"), fallback: "Something went wrong.")

      expect(message).to match(expected)
      expect(message).to include("The model `gpt-5.1` does not exist")
    end
  end

  it "says the configured model isn't available" do
    message = described_class.message_for(RubyLLM::ModelNotFoundError.new("Unknown model: gpt-5.1"), fallback: "x")

    expect(message).to include("gpt-5.1", "model")
  end
end
