module Llm
  # Asks a (schema-bound) chat, validates the response against that same
  # schema, and retries once with the validation errors appended before
  # giving up (apps/api/AGENTS.md's AI-service contract). Shared by every
  # Assemble stage that calls the LLM with a JSON Schema, so the retry loop
  # lives in one place.
  class StructuredAsk
    class ValidationError < StandardError; end

    MAX_ATTEMPTS = 2

    def self.call(chat:, schema:, prompt:)
      ask(chat, JSONSchemer.schema(schema), prompt, attempt: 1)
    end

    def self.ask(chat, validator, message, attempt:)
      content = chat.ask(message).content
      errors = validator.validate(content).to_a
      return content if errors.empty?

      summary = errors.map { JSONSchemer::Errors.pretty(_1) }.join("; ")
      raise ValidationError, summary if attempt >= MAX_ATTEMPTS

      ask(chat, validator, "Your previous output failed validation: #{summary}. Please correct it.", attempt: attempt + 1)
    end
    private_class_method :ask
  end
end
