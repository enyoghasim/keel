require "rails_helper"

RSpec.describe "Api::Departments", type: :request do
  describe "GET /api/companies/:company_id/departments" do
    it "lists the company's departments" do
      company = create(:company)
      engineering = create(:department, company: company, name: "Engineering")
      create(:department) # a different company's department, must not show up

      get "/api/companies/#{company.id}/departments"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["data"]
      expect(body).to contain_exactly(hash_including("id" => engineering.id, "name" => "Engineering"))
    end
  end

  describe "GET /api/companies/:company_id/departments/:id" do
    it "returns the department, including its head" do
      company = create(:company)
      head = create(:person, company: company)
      department = create(:department, company: company, head: head)

      get "/api/companies/#{company.id}/departments/#{department.id}"

      body = response.parsed_body["data"]
      expect(body).to include("id" => department.id, "head_id" => head.id)
    end

    it "returns a 404 envelope for a department in a different company" do
      company = create(:company)
      other_department = create(:department)

      get "/api/companies/#{company.id}/departments/#{other_department.id}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
