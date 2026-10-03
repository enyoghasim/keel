require "rails_helper"

RSpec.describe Integration, type: :model do
  it "round-trips credentials through encryption, unreadable from the raw column" do
    integration = create(:integration, kind: "slack", credentials: { "webhook_url" => "https://hooks.slack.com/services/abc" })

    expect(integration.reload.credentials).to eq({ "webhook_url" => "https://hooks.slack.com/services/abc" })
    raw = ActiveRecord::Base.connection.select_value("SELECT credentials FROM integrations WHERE id = #{integration.id}")
    expect(raw).not_to include("hooks.slack.com")
  end

  it "allows only one integration per kind per company" do
    company = create(:company)
    create(:integration, company: company, kind: "slack")

    expect(build(:integration, company: company, kind: "slack")).not_to be_valid
  end

  it "requires a known kind" do
    expect(build(:integration, kind: "carrier_pigeon")).not_to be_valid
  end
end
