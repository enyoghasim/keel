require "rails_helper"

RSpec.describe "Api::Workspace", type: :request do
  # The browser has no company id of its own: the backend says which company
  # this deployment serves, so a fresh browser lands on the right page.
  describe "GET /api/workspace" do
    it "has no company on a blank deployment" do
      get "/api/workspace"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to eq({ "company" => nil, "demo_reset" => false })
    end

    it "names the company the deployment serves, without needing a sign-in" do
      company = create(:company, name: "Factorial Logistics")
      create(:company, name: "Later Co")

      get "/api/workspace"

      expect(response.parsed_body["data"]["company"]).to include("id" => company.id, "name" => "Factorial Logistics", "assembling" => false)
    end

    it "says whether this deployment lets a signed-in admin reset the demo" do
      allow(Demo::Reset).to receive(:enabled?).and_return(true)

      get "/api/workspace"

      expect(response.parsed_body["data"]["demo_reset"]).to be(true)
    end

    it "says the company is still assembling while its roster import has stages left" do
      company = create(:company)
      company.roster_csv.attach(io: StringIO.new("Name\nAda"), filename: "roster.csv", content_type: "text/csv")
      company.update!(assemble_completed_stages: %w[csv_mapping])

      get "/api/workspace"
      expect(response.parsed_body["data"]["company"]["assembling"]).to be(true)

      company.update!(assemble_completed_stages: AssembleJob::STAGES)
      get "/api/workspace"
      expect(response.parsed_body["data"]["company"]["assembling"]).to be(false)
    end
  end
end
