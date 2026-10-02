module Llm
  # What to tell a person when a model call fails. Only a missing key is
  # worth explaining — it is the one failure they can do something about —
  # everything else keeps the caller's own wording.
  module Failure
    NO_MODEL = "Keel's AI model isn't set up on this deployment: no model API key is configured. " \
               "An admin can set OPENAI_API_KEY (or ANTHROPIC_API_KEY) and restart.".freeze

    def self.message_for(error, fallback:)
      error.is_a?(RubyLLM::ConfigurationError) ? NO_MODEL : fallback
    end
  end
end
