module Llm
  # Loads packages/schemas/schemas/*.schema.json — the single source of
  # truth, shared with the TypeScript side via json-schema-to-typescript,
  # for every shape an LLM is allowed to produce (packages/schemas/AGENTS.md).
  class SchemaRegistry
    SCHEMAS_DIR = Rails.root.join("..", "..", "packages", "schemas", "schemas")

    def self.fetch(name)
      registry.fetch(name) { raise KeyError, "unknown schema '#{name}' (looked in #{SCHEMAS_DIR})" }
    end

    def self.registry
      @registry ||= Dir.glob(SCHEMAS_DIR.join("*.schema.json")).each_with_object({}) do |path, acc|
        acc[File.basename(path, ".schema.json")] = JSON.parse(File.read(path))
      end
    end
  end
end
