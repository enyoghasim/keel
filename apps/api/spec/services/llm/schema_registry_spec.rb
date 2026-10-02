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
end
