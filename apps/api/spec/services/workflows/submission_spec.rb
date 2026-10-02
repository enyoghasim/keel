require "rails_helper"

RSpec.describe Workflows::Submission do
  # The one path every new request takes (the HTTP endpoint and the agent's
  # create_request tool alike): save it, let Rules::Engine decide, and have
  # Workflows::Runtime route it.
  it "saves the request and lets the engine auto-approve it when an active rule says so" do
    company = create(:company)
    requester = create(:person, company: company)
    policy = create(:policy, company: company, category: "expense", status: "active")
    create(:rule, policy: policy, status: "active", key: "small_expense",
                   conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 },
                   actions: { "decision" => "auto_approve" })

    request = described_class.call(company: company, requester: requester, kind: "expense", payload: { "amount_eur" => 100 })

    expect(request).to be_persisted
    expect(request).to have_attributes(decision: "auto_approve", status: "approved", matched_rule_ids: [ "small_expense" ])
  end

  it "saves nothing when the runtime can't route the request" do
    company = create(:company)
    requester = create(:person, company: company, manager: create(:person, company: company))
    policy = create(:policy, company: company, category: "expense", status: "active")
    create(:rule, policy: policy, status: "active", key: "big_expense",
                   conditions: { "field" => "payload.amount_eur", "op" => "gt", "value" => 500 },
                   actions: { "decision" => "require_approval", "approvers" => [ "manager_of(requester)" ] })

    expect { described_class.call(company: company, requester: requester, kind: "expense", payload: { "amount_eur" => 900 }) }
      .to raise_error(ArgumentError, /no active workflow/)
    expect(Request.count).to eq(0)
  end
end
