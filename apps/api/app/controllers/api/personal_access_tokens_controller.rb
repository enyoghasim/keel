module Api
  # A person's own MCP tokens (SPEC.md section 13). The raw token is in the
  # create response only; after that just its name and usage are visible.
  class PersonalAccessTokensController < ApplicationController
    include CompanyScoped

    before_action :require_current_person!

    def index
      render_success(data: tokens.active.order(:id).map { serialize(_1) })
    end

    def create
      token, raw = PersonalAccessToken.issue!(current_person, name: params[:name].to_s.strip)
      render_success(data: serialize(token).merge("token" => raw), message: "Token created. Copy it now; it won't be shown again.", status: :created)
    rescue ActiveRecord::RecordInvalid => e
      render_error(message: e.message, errors: e.record.errors.full_messages)
    end

    def destroy
      tokens.active.find(params[:id]).update!(revoked_at: Time.current)
      render_success(message: "Token revoked.")
    end

    private

    def tokens = current_person.personal_access_tokens

    def serialize(token) = token.as_json(only: PersonalAccessToken::FIELDS)
  end
end
