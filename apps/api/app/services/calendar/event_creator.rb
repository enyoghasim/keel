module Calendar
  # Creates a real event on a company's connected Google Calendar (SPEC.md
  # section 8's workflow side effects) — the Calendar counterpart to
  # Slack::Notifier. Event content is derived from context by the caller
  # (StepSideEffectJob), not templated per-step, same reasoning Slack's
  # message is built in the job rather than stored on the step.
  class EventCreator
    EVENTS_URL = "https://www.googleapis.com/calendar/v3/calendars/primary/events".freeze

    def self.call(company:, summary:, attendee_person: nil, starts_at: Time.current, ends_at: Time.current + 1.day)
      new(company).call(summary: summary, attendee_person: attendee_person, starts_at: starts_at, ends_at: ends_at)
    end

    def initialize(company) = (@integration = company.integrations.find_by!(kind: "google_calendar", status: "connected"))

    def call(summary:, attendee_person:, starts_at:, ends_at:)
      access_token = TokenRefresher.call(@integration)

      response = Faraday.post(EVENTS_URL) do |request|
        request.headers["Authorization"] = "Bearer #{access_token}"
        request.headers["Content-Type"] = "application/json"
        request.body = event_body(summary, attendee_person, starts_at, ends_at).to_json
      end
      raise "Google Calendar returned #{response.status}" unless response.success?

      JSON.parse(response.body).fetch("id")
    end

    private

    def event_body(summary, attendee_person, starts_at, ends_at)
      body = { summary: summary, start: { date: starts_at.to_date.iso8601 }, end: { date: ends_at.to_date.iso8601 } }
      body[:attendees] = [ { email: attendee_person.email } ] if attendee_person
      body
    end
  end
end
