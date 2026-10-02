require "rails_helper"

RSpec.describe Session, type: :model do
  describe ".start!" do
    it "creates a session and returns a raw token that authenticates back to it" do
      person = create(:person)

      session, token = Session.start!(person)

      expect(Session.authenticate(token)).to eq(session)
    end

    it "does not store the raw token in the database" do
      person = create(:person)

      _session, token = Session.start!(person)

      expect(Session.pluck(:token_digest)).not_to include(token)
    end

    it "sets an expiry in the future" do
      person = create(:person)

      session, _token = Session.start!(person)

      expect(session.expires_at).to be_within(1.second).of(Session::EXPIRY.from_now)
    end
  end

  describe ".authenticate" do
    it "returns nil for an unknown token" do
      expect(Session.authenticate("not-a-real-token")).to be_nil
    end

    it "returns nil for a blank token" do
      expect(Session.authenticate(nil)).to be_nil
      expect(Session.authenticate("")).to be_nil
    end

    it "returns nil for an expired session" do
      person = create(:person)
      _session, token = Session.start!(person)
      Session.last.update!(expires_at: 1.minute.ago)

      expect(Session.authenticate(token)).to be_nil
    end
  end
end
