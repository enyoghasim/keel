require "rails_helper"

RSpec.describe "Api::AssembleEvents", type: :request do
  describe "GET /api/companies/:company_id/assemble_events" do
    it "returns the events AssembleJob has recorded so far, in order" do
      company = create(:company, assemble_events: [
        { "seq" => 0, "stage" => "csv", "event" => "mapping_complete", "data" => {}, "progress" => 0.1 },
        { "seq" => 1, "stage" => "graph", "event" => "person_added", "data" => { "id" => 1 }, "progress" => 0.2 }
      ])

      get "/api/companies/#{company.id}/assemble_events"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].map { _1["seq"] }).to eq([ 0, 1 ])
    end

    it "needs no sign-in, since Assemble runs before anyone exists to sign in" do
      get "/api/companies/#{create(:company).id}/assemble_events"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to eq([])
    end
  end
end
