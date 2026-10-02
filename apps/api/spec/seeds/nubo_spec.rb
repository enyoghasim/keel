require "rails_helper"

# db/seeds.rb builds the Nubo Logistics demo company (SPEC.md section 16):
# the graph, the handbook and its rules, workflows, and three months of
# request history run through the real engine and runtime.
RSpec.describe "db/seeds.rb" do
  def seed! = load Rails.root.join("db/seeds.rb")

  # The history alone is ~600 requests through the real runtime, so seed
  # once for the whole file instead of once per example (the examples only
  # read). Outside the per-example transaction, hence the explicit cleanup.
  before(:all) { load Rails.root.join("db/seeds.rb") }
  after(:all) { ActiveRecord::Base.connection.execute("TRUNCATE companies, prompt_versions RESTART IDENTITY CASCADE") }

  let(:company) { Company.find_by!(name: "Nubo Logistics") }

  def person(name) = company.people.find_by!(name: name)

  describe "the company graph" do
    it "is a 78-person company in nine departments across three offices" do
      expect(company.people.count).to eq(78)
      expect(company.departments.pluck(:name)).to match_array(
        %w[Leadership Operations Sales Engineering Finance People IT] + [ "Customer Support", "Warehouse" ]
      )
      expect(company.people.distinct.pluck(:location)).to match_array(%w[Lagos Abuja Barcelona])
    end

    it "gives the CEO no manager, and every department a head" do
      expect(company.people.where(manager_id: nil).pluck(:title)).to eq([ "CEO" ])
      expect(company.departments.where(head_id: nil)).to be_empty
    end

    it "sets up the people the demo flows rely on" do
      expect(person("Ifeoma Adeyemi").roles).to include("hr_admin")
      expect(person("Amaka Obi").roles).to include("finance_lead")
      expect(person("Emeka Nnadi").roles).to include("it_admin")
      expect(person("Ngozi Eze").manager).to eq(person("Tunde Bakare"))
      expect(person("Tunde Bakare").manager.title).to eq("COO")
      expect(person("Ada Nwosu").direct_reports.count).to eq(6)
      expect(person("Chioma Okafor").department.name).to eq("Finance")
    end

    it "lets any seeded person sign in with the demo password" do
      expect(person("Ifeoma Adeyemi").authenticate(Person::DEMO_PASSWORD)).to be_truthy
    end
  end

  describe "the handbook and its rules" do
    it "stores the handbook as chunks, including a history section that yields no rules" do
      document = company.source_documents.sole
      expect(document.filename).to eq("nubo_handbook.pdf")
      expect(document.chunks.pluck(:text).join).to include("founded in 2014")
      expect(Rule.joins(:source_chunk).where("chunks.text LIKE ?", "%founded in 2014%")).to be_empty
    end

    it "traces every rule to a verbatim quote in its source chunk" do
      rules = Rule.joins(:policy).where(policies: { company_id: company.id })
      expect(rules).not_to be_empty
      expect(rules).to all(satisfy { |rule| rule.source_chunk.text.include?(rule.source_quote) })
    end

    it "activates the leave, expense and equipment policies the runtime needs" do
      %w[leave expense equipment].each do |category|
        expect(company.active_rule_definitions(category)).not_to be_empty
      end
    end

    it "plants the deliberate ambiguities as rules that are not enforced yet" do
      conference = Rule.find_by!(key: "expense_conference_engineering")
      expect(conference.status).to eq("extracted")
      expect(conference.ambiguities).not_to be_empty
      expect(company.active_rule_definitions("expense").map(&:key)).not_to include(conference.key)

      remote = company.policies.find_by!(category: "remote")
      expect(remote.status).to eq("needs_review")
      expect(remote.rules.flat_map(&:ambiguities)).not_to be_empty
    end

    it "plants the travel-vs-expense conflict for Rules::ConflictDetector to find" do
      conflicts = Rules::ConflictDetector.call(company.active_rule_definitions("expense"))

      expect(conflicts.map { [ _1.rule_a_key, _1.rule_b_key ].sort }).to include(%w[expense_over_500_manager expense_travel_under_800_auto])
    end

    it "has an active workflow for every request kind" do
      expect(company.workflows.where(status: "active").map { _1.trigger["request_kind"] }).to match_array(%w[leave expense equipment])
    end
  end

  describe "three months of history" do
    it "creates roughly the requested volume of each kind, all inside July to September 2026" do
      counts = company.requests.group(:kind).count

      expect(counts["expense"]).to be_between(380, 420)
      expect(counts["leave"]).to be_between(140, 160)
      expect(counts["equipment"]).to be_between(25, 35)
      expect(company.requests.pluck(:created_at)).to all(be_between(Time.utc(2026, 7, 1), Time.utc(2026, 10, 1)))
    end

    it "decided every request with the real engine, so none is blocked" do
      expect(company.requests.pluck(:decision).uniq).to all(be_in(%w[auto_approve require_approval reject]))
      expect(company.requests.where(status: "blocked")).to be_empty
    end

    it "draws expense amounts from a long tail: mostly small, some over €1,000" do
      amounts = company.requests.where(kind: "expense").map { _1.payload["amount_eur"] }

      expect(amounts.count { _1.between?(50, 400) }).to be > amounts.size / 2
      expect(amounts.count { _1 > 1_000 }).to be > 5
    end

    it "overrides about 5% of decided requests, always with a reason" do
      step_runs = StepRun.joins(workflow_run: :request).where(requests: { company_id: company.id })
      overridden = step_runs.where(overridden: true)

      expect(overridden.count.to_f / company.requests.count).to be_between(0.02, 0.09)
      expect(overridden.pluck(:override_reason)).to all(be_present)
    end

    it "gives approvals realistic acted_at times after the request was made" do
      acted = StepRun.joins(workflow_run: :request).where(requests: { company_id: company.id }, status: "done")
                     .where.not(step_runs: { step_key: "system" })
                     .pluck("step_runs.acted_at", "requests.created_at")

      expect(acted).not_to be_empty
      expect(acted).to all(satisfy { |acted_at, created_at| acted_at > created_at })
    end
  end

  it "is idempotent: running it twice changes nothing" do
    expect { seed! }.not_to change { [ Company.count, Person.count, Request.count, Rule.count, Workflow.count ] }
  end
end
