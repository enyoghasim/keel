require "rails_helper"

RSpec.describe "Api::People", type: :request do
  describe "GET /api/companies/:company_id/people" do
    it "lists the company's people" do
      company = create(:company)
      department = create(:department, company: company)
      manager = create(:person, company: company, department: department)
      report = create(:person, company: company, department: department, manager: manager)
      create(:person) # a different company's person, must not show up

      get "/api/companies/#{company.id}/people"

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body["data"].map { _1["id"] }
      expect(ids).to contain_exactly(manager.id, report.id)
    end
  end

  describe "GET /api/companies/:company_id/people/:id" do
    it "returns the person" do
      company = create(:company)
      department = create(:department, company: company)
      person = create(:person, company: company, department: department, title: "Engineer", roles: [ "finance_lead" ])

      get "/api/companies/#{company.id}/people/#{person.id}"

      body = response.parsed_body["data"]
      expect(body).to include(
        "id" => person.id, "name" => person.name, "title" => "Engineer",
        "department_id" => department.id, "roles" => [ "finance_lead" ]
      )
    end

    it "returns a 404 envelope for a person in a different company" do
      company = create(:company)
      other_person = create(:person)

      get "/api/companies/#{company.id}/people/#{other_person.id}"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["success"]).to eq(false)
    end
  end
end
