module Calendar
  # Keeps a Google Calendar integration's access token usable: Google's
  # access tokens are short-lived (about an hour), so every real call
  # refreshes first when the stored one is at or near expiry, using the
  # long-lived refresh token obtained once at connect time.
  class TokenRefresher
    TOKEN_URL = "https://oauth2.googleapis.com/token".freeze
    EXPIRY_LEEWAY = 2.minutes

    def self.call(integration) = new(integration).call

    def initialize(integration) = @integration = integration

    def call
      return @integration.credentials.fetch("access_token") unless near_expiry?

      response = Faraday.post(TOKEN_URL) do |request|
        request.headers["Content-Type"] = "application/x-www-form-urlencoded"
        request.body = URI.encode_www_form(
          client_id: ENV.fetch("GOOGLE_CALENDAR_CLIENT_ID"),
          client_secret: ENV.fetch("GOOGLE_CALENDAR_CLIENT_SECRET"),
          refresh_token: @integration.credentials.fetch("refresh_token"),
          grant_type: "refresh_token"
        )
      end
      raise "Google token refresh returned #{response.status}" unless response.success?

      data = JSON.parse(response.body)
      @integration.update!(credentials: @integration.credentials.merge(
        "access_token" => data.fetch("access_token"), "expires_at" => (Time.current + data.fetch("expires_in").to_i).iso8601
      ))
      data.fetch("access_token")
    end

    private

    def near_expiry? = Time.zone.parse(@integration.credentials.fetch("expires_at")) <= EXPIRY_LEEWAY.from_now
  end
end
