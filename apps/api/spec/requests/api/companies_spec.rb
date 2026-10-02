require "rails_helper"

RSpec.describe "Api::Companies", type: :request do
  def roster_csv_signed_id
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("Name\nAda Nwosu"), filename: "roster.csv", content_type: "text/csv"
    ).signed_id
  end

  def handbook_signed_id
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("handbook text"), filename: "handbook.pdf", content_type: "application/pdf"
    ).signed_id
  end

  describe "POST /api/companies" do
    it "creates a company, attaches the roster csv, and enqueues AssembleJob" do
      expect {
        post "/api/companies", params: { company: { name: "Acme", roster_csv: roster_csv_signed_id } }
      }.to have_enqueued_job(AssembleJob)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["success"]).to eq(true)
      expect(body["data"]["name"]).to eq("Acme")
      expect(Company.last.roster_csv).to be_attached
    end

    it "refuses a second company: a deployment serves one" do
      create(:company, name: "Nubo Logistics")

      expect {
        post "/api/companies", params: { company: { name: "Acme", roster_csv: roster_csv_signed_id } }
      }.not_to have_enqueued_job(AssembleJob)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to match(/already has a company/)
      expect(Company.count).to eq(1)
    end

    it "attaches the handbook as a source document when provided" do
      post "/api/companies", params: {
        company: { name: "Acme", roster_csv: roster_csv_signed_id, handbook: handbook_signed_id }
      }

      document = Company.last.source_documents.sole
      expect(document.kind).to eq("handbook")
      expect(document.file).to be_attached
    end

    it "does not attach a source document when no handbook is given" do
      post "/api/companies", params: { company: { name: "Acme", roster_csv: roster_csv_signed_id } }

      expect(Company.last.source_documents).to be_empty
    end

    it "returns a validation error envelope when name is missing" do
      post "/api/companies", params: { company: { roster_csv: roster_csv_signed_id } }

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body["success"]).to eq(false)
      expect(body["errors"]).to include("Name can't be blank")
    end

    it "returns an error envelope when roster_csv is missing" do
      post "/api/companies", params: { company: { name: "Acme" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["success"]).to eq(false)
    end

    it "does not enqueue AssembleJob when creation fails" do
      expect {
        post "/api/companies", params: { company: { name: "Acme" } }
      }.not_to have_enqueued_job(AssembleJob)
    end
  end

  describe "GET /api/companies/:id" do
    it "returns the company with its assemble progress" do
      company = create(:company, assemble_completed_stages: [ "csv_mapping" ])

      get "/api/companies/#{company.id}"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["data"]
      expect(body["id"]).to eq(company.id)
      expect(body["assemble_completed_stages"]).to eq([ "csv_mapping" ])
    end

    it "returns a 404 envelope for an unknown company" do
      get "/api/companies/999999"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["success"]).to eq(false)
    end
  end
end
