require "rails_helper"

RSpec.describe PersonalAccessToken, type: :model do
  describe ".issue!" do
    it "returns the record and the raw token, storing only the token's digest" do
      person = create(:person)

      token, raw = described_class.issue!(person, name: "Claude Desktop")

      expect(raw).to start_with("keel_pat_")
      expect(token).to have_attributes(person: person, name: "Claude Desktop", token_digest: described_class.digest(raw))
      expect(token.token_digest).not_to include(raw)
    end
  end

  describe ".authenticate" do
    it "finds the token by its raw value and records when it was last used" do
      token, raw = described_class.issue!(create(:person), name: "x")

      expect(described_class.authenticate(raw)).to eq(token)
      expect(token.reload.last_used_at).to be_within(5.seconds).of(Time.current)
    end

    it "returns nil for a blank, unknown or revoked token" do
      token, raw = described_class.issue!(create(:person), name: "x")

      expect(described_class.authenticate(nil)).to be_nil
      expect(described_class.authenticate("keel_pat_nope")).to be_nil
      token.update!(revoked_at: Time.current)
      expect(described_class.authenticate(raw)).to be_nil
    end
  end

  it "requires a name" do
    expect(build(:personal_access_token, name: "")).not_to be_valid
  end
end
