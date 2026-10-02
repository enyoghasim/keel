module Llm
  # What to tell a person when a model call fails. The provider's own error is
  # the one thing that says what to fix (a bad key, no credit, a model the
  # account can't use), so it is named and passed on; anything else keeps the
  # caller's own wording and goes to the log.
  module Failure
    NO_MODEL = "Keel's AI model isn't set up on this deployment: no model API key is configured. " \
               "An admin can set OPENAI_API_KEY (or ANTHROPIC_API_KEY) and restart.".freeze

    PROVIDER_ERRORS = {
      RubyLLM::UnauthorizedError => "The model provider rejected the API key",
      RubyLLM::ForbiddenError => "The model provider rejected the API key or this account's access to the model",
      RubyLLM::PaymentRequiredError => "The model provider says the account is out of credit (check billing or quota)",
      RubyLLM::RateLimitError => "The model provider's rate limit or quota was hit",
      RubyLLM::BadRequestError => "The model provider refused the request",
      RubyLLM::ContextLengthExceededError => "The request was too long for the model"
    }.freeze

    def self.message_for(error, fallback:)
      return NO_MODEL if error.is_a?(RubyLLM::ConfigurationError)
      return "The configured model isn't available: #{error.message}. Set a model your account can use." if error.is_a?(RubyLLM::ModelNotFoundError)

      lead = PROVIDER_ERRORS.find { |klass, _| error.is_a?(klass) }&.last
      lead ? "#{lead}: #{error.message}" : fallback
    end
  end
end
