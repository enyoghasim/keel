module Assemble
  # Stage 1 of the Assemble pipeline (SPEC.md section 6): asks the LLM to
  # map an uploaded CSV's header row to Keel's person fields from a small
  # sample, then hands the mapping back for Ruby to apply to every row.
  # The LLM never sees the full file.
  class CsvMapper
    ValidationError = Llm::StructuredAsk::ValidationError

    FIELDS = %w[name email title department manager location start_date ignore].freeze

    Mapping = Data.define(:source_column, :field, :confidence)

    def self.call(headers:, sample_rows:)
      schema = Llm::SchemaRegistry.fetch("csv-mapping")
      chat = RubyLLM.chat.with_schema(schema)

      data = Llm::StructuredAsk.call(chat: chat, schema: schema, prompt: prompt(headers, sample_rows))
      data.fetch("mappings").map { |m| Mapping.new(m.fetch("source_column"), m.fetch("field"), m.fetch("confidence")) }
    end

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
