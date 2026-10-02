require "rails_helper"

RSpec.describe Chunk, type: :model do
  it "is valid with a source document, page, position and text" do
    expect(build(:chunk)).to be_valid
  end

  it "requires text" do
    chunk = build(:chunk, text: nil)

    expect(chunk).not_to be_valid
    expect(chunk.errors[:text]).to be_present
  end

  it "requires a source document" do
    chunk = build(:chunk, source_document: nil)

    expect(chunk).not_to be_valid
    expect(chunk.errors[:source_document]).to be_present
  end

  it "stores and retrieves its embedding vector" do
    chunk = create(:chunk, embedding: Array.new(1536) { 0.001 })

    expect(chunk.reload.embedding.length).to eq(1536)
  end

  it "orders other chunks by distance to a query vector" do
    document = create(:source_document)
    origin = Array.new(1536, 0.0)
    close = create(:chunk, source_document: document, embedding: [ 0.1 ] + origin[1..])
    far = create(:chunk, source_document: document, embedding: [ 10.0 ] + origin[1..])

    nearest = Chunk.nearest_neighbors(:embedding, origin, distance: "euclidean").to_a

    expect(nearest).to eq([ close, far ])
  end
end
