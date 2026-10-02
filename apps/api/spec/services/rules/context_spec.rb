require "rails_helper"

RSpec.describe Rules::Context do
  describe ".build" do
    it "flattens the requester's department, location and payload fields" do
      company = create(:company)
      department = create(:department, company: company, name: "Engineering")
      requester = create(:person, company: company, department: department, location: "Lagos")
      snapshot = Org::GraphSnapshot.load(company)
      request = Rules::RequestInput.new(
        requester_id: requester.id,
        payload: { "amount_eur" => 900, "category" => "conference", "days" => nil, "notice_days" => nil },
      )

      ctx = described_class.build(request, snapshot)

      expect(ctx).to include(
        "requester.department" => "Engineering",
        "requester.location" => "Lagos",
        "payload.amount_eur" => 900,
        "payload.category" => "conference",
      )
    end

    it "computes tenure_months from the requester's start_date" do
      company = create(:company)
      requester = create(:person, company: company, start_date: 14.months.ago.to_date)
      snapshot = Org::GraphSnapshot.load(company)
      request = Rules::RequestInput.new(requester_id: requester.id, payload: {})

      ctx = described_class.build(request, snapshot)

      expect(ctx["requester.tenure_months"]).to eq(14)
    end

    it "is nil for tenure_months when the requester has no start_date" do
      company = create(:company)
      requester = create(:person, company: company, start_date: nil)
      snapshot = Org::GraphSnapshot.load(company)
      request = Rules::RequestInput.new(requester_id: requester.id, payload: {})

      ctx = described_class.build(request, snapshot)

      expect(ctx["requester.tenure_months"]).to be_nil
    end

    it "is nil for requester.department when the requester has no department" do
      company = create(:company)
      requester = create(:person, company: company, department: nil)
      snapshot = Org::GraphSnapshot.load(company)
      request = Rules::RequestInput.new(requester_id: requester.id, payload: {})

      ctx = described_class.build(request, snapshot)

      expect(ctx["requester.department"]).to be_nil
    end
  end
end
