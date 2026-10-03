module Slack
  # Posts a message to a company's connected Slack incoming webhook. Plain
  # I/O, deterministic, no LLM — lives alongside org/, rules/, workflows/,
  # not assemble/ or agent/.
  class Notifier
    def self.call(company:, text:) = new(company).call(text)

    def initialize(company)
      @integration = company.integrations.find_by!(kind: "slack", status: "connected")
    end

    def call(text)
      response = Faraday.post(@integration.credentials.fetch("webhook_url")) do |request|
        request.headers["Content-Type"] = "application/json"
        request.body = { text: text }.to_json
      end
      raise "Slack webhook returned #{response.status}" unless response.success?
    end
  end
end
