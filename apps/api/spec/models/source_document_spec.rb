require "rails_helper"

RSpec.describe SourceDocument, type: :model do
  it "is valid with a company, filename and kind" do
    expect(build(:source_document)).to be_valid
  end

  it "requires a filename" do
    document = build(:source_document, filename: nil)

    expect(document).not_to be_valid
    expect(document.errors[:filename]).to be_present
  end

  it "requires a kind" do
    document = build(:source_document, kind: nil)

    expect(document).not_to be_valid
    expect(document.errors[:kind]).to be_present
  end

  it "has many chunks" do
    document = create(:source_document)
    chunk = create(:chunk, source_document: document)

    expect(document.chunks).to contain_exactly(chunk)
  end
end
