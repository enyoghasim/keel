require "rails_helper"

RSpec.describe "Api::DemoResets", type: :request do
  let(:company) { create(:company) }
  let(:hr) { create(:person, :hr_admin, company: company) }
  let(:path) { "/api/companies/#{company.id}/demo_reset" }

  before { allow(Demo::Reset).to receive(:call) }

  context "on a deployment with DEMO_RESET on" do
    before { allow(Demo::Reset).to receive(:enabled?).and_return(true) }

    it "reloads the demo company for an hr_admin" do
      sign_in(hr)

      post path, as: :json

      expect(response).to have_http_status(:ok)
      expect(Demo::Reset).to have_received(:call)
    end

    it "is for hr_admins only" do
      sign_in(create(:person, company: company))

      post path, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(Demo::Reset).not_to have_received(:call)
    end

    it "requires sign-in" do
      post path, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "does not exist on a deployment that has not turned DEMO_RESET on, whoever asks" do
    allow(Demo::Reset).to receive(:enabled?).and_return(false)
    sign_in(hr)

    post path, as: :json

    expect(response).to have_http_status(:not_found)
    expect(Demo::Reset).not_to have_received(:call)
  end
end
