module Llm
  # Asks a (schema-bound) chat, validates the response against that same
  # schema, and retries once with the validation errors appended before
  # giving up (apps/api/AGENTS.md's AI-service contract). Shared by every
  # Assemble stage that calls the LLM with a JSON Schema, so the retry loop
  # lives in one place.
  #
  # Pass a block to learn what the model calls cost: it receives each
  # attempt's cost in USD (retries included), skipping a model ruby_llm has
  # no pricing for. Evals use it to put judge and compile spend on the run.
  class StructuredAsk
    class ValidationError < StandardError; end

    MAX_ATTEMPTS = 2

    def self.call(chat:, schema:, prompt:, &on_cost)
      ask(chat, JSONSchemer.schema(schema), prompt, attempt: 1, on_cost: on_cost)
    end

    def self.ask(chat, validator, message, attempt:, on_cost:)
      reply = chat.ask(message)
      content = reply.content
      if on_cost && (cost = reply.cost.total)
        on_cost.call(cost)
      end
      errors = validator.validate(content).to_a
      return content if errors.empty?

      summary = errors.map { JSONSchemer::Errors.pretty(_1) }.join("; ")
      raise ValidationError, summary if attempt >= MAX_ATTEMPTS

      ask(chat, validator, "Your previous output failed validation: #{summary}. Please correct it.", attempt: attempt + 1, on_cost: on_cost)
    end
    private_class_method :ask
  end
end
