require "rails_helper"

RSpec.describe Org::Resolver do
  def snapshot_for(company) = Org::GraphSnapshot.load(company)

  describe "#resolve" do
    it "resolves 'requester' to the requester themself" do
      company = create(:company)
      person = create(:person, company: company)
      resolver = described_class.new(snapshot_for(company))

      result = resolver.resolve("requester", requester_id: person.id)

      expect(result.person_ids).to eq([ person.id ])
      expect(result.error).to be_nil
    end

    it "resolves 'manager_of(requester)' to the requester's manager" do
      company = create(:company)
      manager = create(:person, company: company)
      requester = create(:person, company: company, manager: manager)
      resolver = described_class.new(snapshot_for(company))

      result = resolver.resolve("manager_of(requester)", requester_id: requester.id)

      expect(result.person_ids).to eq([ manager.id ])
      expect(result.error).to be_nil
    end

    it "fails to resolve 'manager_of(requester)' when the requester has no manager" do
      company = create(:company)
      ceo = create(:person, :without_manager, company: company)
      resolver = described_class.new(snapshot_for(company))

      result = resolver.resolve("manager_of(requester)", requester_id: ceo.id)

      expect(result.person_ids).to eq([])
      expect(result.error).to eq("manager_of(requester) resolved to nobody")
    end

    it "resolves 'skip_manager_of(requester)' to the manager's manager" do
      company = create(:company)
      skip_manager = create(:person, company: company)
      manager = create(:person, company: company, manager: skip_manager)
      requester = create(:person, company: company, manager: manager)
      resolver = described_class.new(snapshot_for(company))

      result = resolver.resolve("skip_manager_of(requester)", requester_id: requester.id)

      expect(result.person_ids).to eq([ skip_manager.id ])
      expect(result.error).to be_nil
    end

    it "fails to resolve 'skip_manager_of(requester)' when the manager has no manager" do
      company = create(:company)
      manager = create(:person, :without_manager, company: company)
      requester = create(:person, company: company, manager: manager)
      resolver = described_class.new(snapshot_for(company))

      result = resolver.resolve("skip_manager_of(requester)", requester_id: requester.id)

      expect(result.person_ids).to eq([])
      expect(result.error).to eq("skip_manager_of(requester) resolved to nobody")
    end

    it "resolves 'head_of(requester.department)' to the department head" do
      company = create(:company)
      department = create(:department, company: company)
      head = create(:person, company: company, department: department)
      department.update!(head: head)
      requester = create(:person, company: company, department: department)
      resolver = described_class.new(snapshot_for(company))

      result = resolver.resolve("head_of(requester.department)", requester_id: requester.id)

      expect(result.person_ids).to eq([ head.id ])
      expect(result.error).to be_nil
    end

    it "fails to resolve 'head_of(requester.department)' when the department has no head" do
      company = create(:company)
      department = create(:department, company: company, head: nil)
      requester = create(:person, company: company, department: department)
      resolver = described_class.new(snapshot_for(company))

      result = resolver.resolve("head_of(requester.department)", requester_id: requester.id)

      expect(result.person_ids).to eq([])
      expect(result.error).to eq("head_of(requester.department) resolved to nobody")
    end

    it "resolves 'role:X' to everyone holding that role" do
      company = create(:company)
      requester = create(:person, company: company)
      finance_lead = create(:person, :finance_lead, company: company)
      resolver = described_class.new(snapshot_for(company))

      result = resolver.resolve("role:finance_lead", requester_id: requester.id)

      expect(result.person_ids).to eq([ finance_lead.id ])
      expect(result.error).to be_nil
    end

    it "fails to resolve 'role:X' when nobody holds the role" do
      company = create(:company)
      requester = create(:person, company: company)
      resolver = described_class.new(snapshot_for(company))

      result = resolver.resolve("role:it_admin", requester_id: requester.id)

      expect(result.person_ids).to eq([])
      expect(result.error).to eq("role:it_admin resolved to nobody")
    end

    it "flags self-approval when the requester is the sole resolved approver" do
      company = create(:company)
      requester = create(:person, :finance_lead, company: company)
      resolver = described_class.new(snapshot_for(company))

      result = resolver.resolve("role:finance_lead", requester_id: requester.id)

      expect(result.person_ids).to eq([ requester.id ])
      expect(result.error).to eq("self-approval")
    end

    it "does not flag self-approval for the 'requester' reference itself" do
      company = create(:company)
      requester = create(:person, company: company)
      resolver = described_class.new(snapshot_for(company))

      result = resolver.resolve("requester", requester_id: requester.id)

      expect(result.error).to be_nil
    end

    it "resolves 'person:X' to that specific person, with no further lookup" do
      company = create(:company)
      requester = create(:person, company: company)
      approver = create(:person, company: company)
      resolver = described_class.new(snapshot_for(company))

      result = resolver.resolve("person:#{approver.id}", requester_id: requester.id)

      expect(result.person_ids).to eq([ approver.id ])
      expect(result.error).to be_nil
    end

    it "returns an error for an unknown reference" do
      company = create(:company)
      requester = create(:person, company: company)
      resolver = described_class.new(snapshot_for(company))

      result = resolver.resolve("something_made_up", requester_id: requester.id)

      expect(result.person_ids).to eq([])
      expect(result.error).to eq("unknown reference something_made_up")
    end
  end
end
