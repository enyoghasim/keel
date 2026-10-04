require "rails_helper"

RSpec.describe Agent::Tools::SearchPeople do
  let(:company) { create(:company) }
  let(:asker) { create(:person, company: company) }
  let(:tool) { described_class.new(Agent::Context.new(company: company, person: asker, agent_run: nil)) }

  def call(args) = JSON.parse(tool.call(args))

  it "finds people by name, title or department within the company, with their manager" do
    sales = create(:department, company: company, name: "Sales")
    ada = create(:person, company: company, name: "Ada Nwosu", title: "Head of People")
    ngozi = create(:person, company: company, name: "Ngozi Okafor", title: "Account Executive", department: sales, manager: ada)
    create(:person, company: create(:company), name: "Ngozi Elsewhere")

    by_name = call({ "query" => "ngozi" })
    by_department = call({ "query" => "sales" })

    expect(by_name["people"]).to eq([
      { "id" => ngozi.id, "name" => "Ngozi Okafor", "title" => "Account Executive", "department" => "Sales",
        "department_id" => sales.id, "manager" => "Ada Nwosu", "roles" => [] }
    ])
    expect(by_department["people"].map { _1["name"] }).to eq([ "Ngozi Okafor" ])
  end

  it "treats the query as text, not a LIKE pattern" do
    create(:person, company: company, name: "Ada Nwosu")

    expect(call({ "query" => "%" })["people"]).to eq([])
  end

  it "tells the model what it got wrong rather than raising when an argument is missing" do
    expect(call({})).to eq({ "error" => "Invalid tool arguments: missing keyword: query" })
  end
end
