require "rails_helper"
require_relative "../../db/seeds/factorial_handbook"

RSpec.describe Seeds::FactorialHandbook do
  # SPEC.md section 15, Flow C: a €1,200 client dinner needs the manager's
  # approval and, once approved, the finance notification fires because the
  # amount is over the notify threshold.
  it "notifies finance about an expense of €1,200" do
    finance_notify = described_class::WORKFLOWS.fetch("expense").find { _1["key"] == "finance_notify" }

    expect(Rules::Condition.match?(finance_notify["when"], { "payload.amount_eur" => 1200 })).to be(true)
    expect(Rules::Condition.match?(finance_notify["when"], { "payload.amount_eur" => 400 })).to be(false)
  end
end
