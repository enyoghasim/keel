module Assemble
  # Stage 1 of the Assemble pipeline (SPEC.md section 6): asks the LLM to
  # map an uploaded CSV's header row to Keel's person fields from a small
  # sample, then hands the mapping back for Ruby to apply to every row.
  # The LLM never sees the full file.
  class CsvMapper
    class ValidationError < StandardError; end

    FIELDS = %w[name email title department manager location start_date ignore].freeze
    MAX_ATTEMPTS = 2

    Mapping = Data.define(:source_column, :field, :confidence)

    def self.call(headers:, sample_rows:)
      schema = Llm::SchemaRegistry.fetch("csv-mapping")
      validator = JSONSchemer.schema(schema)
      chat = RubyLLM.chat.with_schema(schema)

      data = ask_with_retry(chat, validator, prompt(headers, sample_rows))
      data.fetch("mappings").map { |m| Mapping.new(m.fetch("source_column"), m.fetch("field"), m.fetch("confidence")) }
    end

    def self.ask_with_retry(chat, validator, message, attempt: 1)
      content = chat.ask(message).content
      errors = validator.validate(content).to_a
      return content if errors.empty?

      summary = errors.map { JSONSchemer::Errors.pretty(_1) }.join("; ")
      raise ValidationError, summary if attempt >= MAX_ATTEMPTS

      ask_with_retry(chat, validator, "Your previous output failed validation: #{summary}. Please correct it.", attempt: attempt + 1)
    end
    private_class_method :ask_with_retry

    def self.prompt(headers, sample_rows)
      rows = sample_rows.map { |row| row.join(", ") }.join("\n")

      <<~PROMPT
        Map each column of this CSV to exactly one Keel field: #{FIELDS.join(', ')}.
        Use "ignore" for a column that doesn't correspond to a person field, and give a
        confidence from 0 to 1 for every mapping.

        Header row: #{headers.join(', ')}
        Sample data rows:
        #{rows}
      PROMPT
    end
    private_class_method :prompt
  end
end
