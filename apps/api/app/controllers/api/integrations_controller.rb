module Api
  # Connects a company to Slack or Google Calendar (SPEC.md section 8's
  # workflow side effects). Credentials are write-only from here on —
  # #serialize never includes them, so a connected integration can only be
  # replaced or disconnected, never read back.
  class IntegrationsController < ApplicationController
    include CompanyScoped
    include HrAdminOnly

    FIELDS = %i[id kind status error_message created_at].freeze
    SLACK_WEBHOOK_PREFIX = "https://hooks.slack.com/".freeze

    before_action :require_current_person!, :require_hr_admin!

    def index
      render_success(data: @company.integrations.order(:id).map { serialize(_1) })
    end

    def create
      case params[:kind]
      when "slack" then connect_slack
      else render_error(message: "Unknown integration kind '#{params[:kind]}'.")
      end
    end

    def destroy
      @company.integrations.find(params[:id]).destroy!
      render_success(message: "Disconnected.")
    end

    private

    def connect_slack
      webhook_url = params[:webhook_url].to_s
      return render_error(message: "That doesn't look like a Slack incoming webhook URL.") unless webhook_url.start_with?(SLACK_WEBHOOK_PREFIX)

      integration = @company.integrations.find_or_initialize_by(kind: "slack")
      integration.update!(status: "connected", credentials: { "webhook_url" => webhook_url }, error_message: nil)
      render_success(data: serialize(integration), message: "Slack connected.", status: :created)
    rescue ActiveRecord::RecordInvalid => e
      render_error(message: e.message, errors: e.record.errors.full_messages)
    end

    def serialize(integration) = integration.as_json(only: FIELDS)
  end
end
