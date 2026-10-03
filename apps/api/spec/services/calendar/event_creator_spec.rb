require "rails_helper"

RSpec.describe Calendar::EventCreator do
  let(:company) { create(:company) }
  let(:attendee) { create(:person, company: company, email: "ngozi@factorial.co") }
  let(:response) { instance_double(Faraday::Response, success?: true, status: 200, body: { id: "evt_123" }.to_json) }

  before do
    create(:integration, company: company, kind: "google_calendar", status: "connected", credentials: {
      "access_token" => "token-abc", "refresh_token" => "refresh-abc", "expires_at" => 1.hour.from_now.iso8601
    })
    allow(Faraday).to receive(:post).and_return(response)
  end

  it "creates an event on the primary calendar and returns its id" do
    event_id = described_class.call(company: company, summary: "Ngozi's leave", attendee_person: attendee,
      starts_at: Date.new(2026, 1, 5), ends_at: Date.new(2026, 1, 8))

    expect(event_id).to eq("evt_123")
    expect(Faraday).to have_received(:post).with("https://www.googleapis.com/calendar/v3/calendars/primary/events")
  end

  it "sends the access token as a bearer header and the event as JSON, including the attendee" do
    headers = {}
    request = instance_double("Faraday::Request", headers: headers)
    allow(request).to receive(:body=)
    allow(Faraday).to receive(:post).and_yield(request).and_return(response)

    described_class.call(company: company, summary: "Ngozi's leave", attendee_person: attendee,
      starts_at: Date.new(2026, 1, 5), ends_at: Date.new(2026, 1, 8))

    expected_body = {
      summary: "Ngozi's leave", start: { date: "2026-01-05" }, end: { date: "2026-01-08" },
      attendees: [ { email: "ngozi@factorial.co" } ]
    }.to_json

    expect(headers["Authorization"]).to eq("Bearer token-abc")
    expect(request).to have_received(:body=).with(expected_body)
  end

  it "omits attendees when no person is given" do
    request = instance_double("Faraday::Request")
    allow(request).to receive(:headers).and_return({})
    allow(request).to receive(:body=)
    allow(Faraday).to receive(:post).and_yield(request).and_return(response)

    described_class.call(company: company, summary: "Company offsite", starts_at: Date.new(2026, 1, 5), ends_at: Date.new(2026, 1, 6))

    expected_body = { summary: "Company offsite", start: { date: "2026-01-05" }, end: { date: "2026-01-06" } }.to_json
    expect(request).to have_received(:body=).with(expected_body)
  end

  it "refreshes a near-expired access token first" do
    integration = company.integrations.find_by!(kind: "google_calendar")
    integration.update!(credentials: integration.credentials.merge("expires_at" => 1.minute.from_now.iso8601))
    refresh_response = instance_double(Faraday::Response, success?: true, status: 200, body: { access_token: "refreshed-token", expires_in: 3600 }.to_json)
    allow(Faraday).to receive(:post).with("https://oauth2.googleapis.com/token").and_return(refresh_response)
    headers = {}
    event_request = instance_double("Faraday::Request", headers: headers)
    allow(event_request).to receive(:body=)
    allow(Faraday).to receive(:post).with("https://www.googleapis.com/calendar/v3/calendars/primary/events").and_yield(event_request).and_return(response)

    described_class.call(company: company, summary: "x")

    expect(headers["Authorization"]).to eq("Bearer refreshed-token")
  end

  it "raises when Google doesn't return success" do
    allow(response).to receive(:success?).and_return(false)
    allow(response).to receive(:status).and_return(500)

    expect { described_class.call(company: company, summary: "x") }.to raise_error(/500/)
  end

  it "raises when the company has no connected Calendar integration" do
    other_company = create(:company)

    expect { described_class.call(company: other_company, summary: "x") }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
