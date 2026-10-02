require "rails_helper"

RSpec.describe Assemble::Levenshtein do
  it "is zero for identical strings" do
    expect(described_class.distance("Tunde Bakare", "Tunde Bakare")).to eq(0)
  end

  it "counts a single substitution" do
    expect(described_class.distance("Tunde Bakare", "Tunde Bakere")).to eq(1)
  end

  it "catches the typo SPEC.md uses as its worked example" do
    expect(described_class.distance("Tunde Bakre", "Tunde Bakare")).to be <= 2
  end

  it "counts insertions and deletions, not just substitutions" do
    expect(described_class.distance("cat", "cats")).to eq(1)
    expect(described_class.distance("cats", "cat")).to eq(1)
  end

  it "treats an empty string as a full insertion or deletion" do
    expect(described_class.distance("", "abc")).to eq(3)
    expect(described_class.distance("abc", "")).to eq(3)
  end
end
