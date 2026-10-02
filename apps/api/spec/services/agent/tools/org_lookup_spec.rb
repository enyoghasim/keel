require "rails_helper"

RSpec.describe Agent::Tools::OrgLookup do
  let(:company) { create(:company) }
  let(:asker) { create(:person, company: company) }
  let(:tool) { described_class.new(Agent::Context.new(company: company, person: asker, agent_run: nil)) }

  def call(args) = JSON.parse(tool.call(args))

  it "returns a person's reporting line up to the CEO, their direct reports and their department head" do
    sales = create(:department, company: company, name: "Sales")
    ceo = create(:person, company: company, name: "Folake Adeniyi", title: "CEO", manager: nil)
    coo = create(:person, company: company, name: "Kelechi Obi", title: "COO", manager: ceo)
    tunde = create(:person, company: company, name: "Tunde Bakare", department: sales, manager: coo)
    sales.update!(head: tunde)
    ngozi = create(:person, company: company, name: "Ngozi Eze", department: sales, manager: tunde, roles: [ "hr_admin" ])
    create(:person, company: company, name: "Chinedu Okonkwo", manager: ngozi)

    result = call({ "person_id" => ngozi.id })

    expect(result["person"]).to include("name" => "Ngozi Eze", "roles" => [ "hr_admin" ])
    expect(result["reporting_line"].map { _1["name"] }).to eq([ "Tunde Bakare", "Kelechi Obi", "Folake Adeniyi" ])
    expect(result["direct_reports"].map { _1["name"] }).to eq([ "Chinedu Okonkwo" ])
    expect(result["department_head"]).to include("name" => "Tunde Bakare")
  end

  it "reports no reporting line for the CEO" do
    ceo = create(:person, company: company, manager: nil)

    expect(call({ "person_id" => ceo.id })["reporting_line"]).to eq([])
  end

  it "won't look up someone from another company" do
    stranger = create(:person, company: create(:company))

    expect(call({ "person_id" => stranger.id })).to include("error" => a_string_matching(/not found/i))
  end

  it "survives a management cycle in bad data rather than looping forever" do
    a = create(:person, company: company)
    b = create(:person, company: company, manager: a)
    a.update!(manager: b)

    expect(call({ "person_id" => a.id })["reporting_line"].size).to be <= Agent::Tools::OrgLookup::MAX_DEPTH
  end
end
