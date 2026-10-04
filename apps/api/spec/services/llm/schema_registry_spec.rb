require "rails_helper"

RSpec.describe Llm::SchemaRegistry do
  it "loads the csv-mapping schema from packages/schemas" do
    schema = described_class.fetch("csv-mapping")

    expect(schema["title"]).to eq("CsvMapping")
    expect(schema.dig("properties", "mappings")).to be_present
  end

  it "raises for an unknown schema name" do
    expect { described_class.fetch("not-a-real-schema") }.to raise_error(KeyError, /not-a-real-schema/)
  end

  # OpenAI's structured-output mode 400s on a "$ref" with any sibling
  # keyword (e.g. {"$ref" => ..., "description" => ...}) — found the hard
  # way when this crashed every single agent eval case via
  # answer-judgement.schema.json. json_schemer (Ruby-side validation)
  # tolerates it, so nothing else here would have caught it.
  it "never pairs a $ref with a sibling keyword, which OpenAI's structured output rejects" do
    described_class.registry.each do |name, schema|
      offenders = refs_with_siblings(schema)
      expect(offenders).to be_empty, "#{name}.schema.json: #{offenders.join('; ')}"
    end
  end

  def refs_with_siblings(node, path = "$")
    offenders = []
    case node
    when Hash
      offenders << "#{path} has $ref alongside #{(node.keys - [ '$ref' ]).join(', ')}" if node.key?("$ref") && node.size > 1
      node.each { |key, value| offenders.concat(refs_with_siblings(value, "#{path}.#{key}")) }
    when Array
      node.each_with_index { |value, i| offenders.concat(refs_with_siblings(value, "#{path}[#{i}]")) }
    end
    offenders
  end
end
