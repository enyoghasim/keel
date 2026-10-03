module Api
  # OAuth2 handshake connecting a company to Google Calendar (SPEC.md
  # section 8's workflow side effects). A full-page browser redirect, not a
  # fetch call — Google's consent screen needs the browser itself, not just
  # an API response. #authorize sends it there with this company signed
  # into "state" (short-lived, no server-side session needed); #callback
  # verifies that signature, exchanges the code for tokens, and stores them
  # on the company's "google_calendar" Integration.
  class GoogleCalendarOauthController < ApplicationController
    include CompanyScoped
    include HrAdminOnly

    AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth".freeze
    TOKEN_URL = "https://oauth2.googleapis.com/token".freeze
    SCOPE = "https://www.googleapis.com/auth/calendar.events".freeze
    STATE_PURPOSE = :google_calendar_oauth

    before_action :require_current_person!, :require_hr_admin!

    def authorize
      query = {
        client_id: ENV.fetch("GOOGLE_CALENDAR_CLIENT_ID"), redirect_uri: ENV.fetch("GOOGLE_CALENDAR_REDIRECT_URI"),
        response_type: "code", access_type: "offline", prompt: "consent", scope: SCOPE, state: state_token
      }.to_query
      redirect_to "#{AUTH_URL}?#{query}", allow_other_host: true
    end

    # The browser is still signed in here (Google's redirect is a normal
    # top-level navigation, so the session cookie survives the round trip),
    # but the signed, short-lived state is what actually proves this
    # request is that same flow and not a forged hit on the callback URL.
    def callback
      raise "Google sign-in didn't complete (#{params[:error] || 'no code returned'})." if params[:code].blank?
      raise "This sign-in link doesn't match this company." unless verified_company_id == @company.id

      connect!(exchange_code(params[:code]))
      redirect_to "/settings"
    rescue StandardError => e
      Rails.logger.error("[GoogleCalendarOauthController] #{e.class}: #{e.message}")
      redirect_to "/settings?#{{ calendar_error: e.message }.to_query}"
    end

    private

    def state_token = Rails.application.message_verifier(STATE_PURPOSE).generate(@company.id, purpose: STATE_PURPOSE, expires_in: 10.minutes)

    def verified_company_id = Rails.application.message_verifier(STATE_PURPOSE).verify(params[:state], purpose: STATE_PURPOSE)

    def exchange_code(code)
      response = Faraday.post(TOKEN_URL) do |request|
        request.headers["Content-Type"] = "application/x-www-form-urlencoded"
        request.body = URI.encode_www_form(
          client_id: ENV.fetch("GOOGLE_CALENDAR_CLIENT_ID"), client_secret: ENV.fetch("GOOGLE_CALENDAR_CLIENT_SECRET"),
          redirect_uri: ENV.fetch("GOOGLE_CALENDAR_REDIRECT_URI"), code: code, grant_type: "authorization_code"
        )
      end
      raise "Google token exchange returned #{response.status}" unless response.success?

      JSON.parse(response.body)
    end

    def connect!(tokens)
      integration = @company.integrations.find_or_initialize_by(kind: "google_calendar")
      integration.update!(status: "connected", error_message: nil, credentials: {
        "access_token" => tokens.fetch("access_token"),
        "refresh_token" => tokens["refresh_token"] || integration.credentials&.dig("refresh_token"),
        "expires_at" => (Time.current + tokens.fetch("expires_in").to_i).iso8601
      })
    end
  end
end
