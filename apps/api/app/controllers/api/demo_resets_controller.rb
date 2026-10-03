module Api
  # "Reset demo" (SPEC.md section 18): wipes the deployment and reloads Demo
  # Factorial. Destructive, so it answers 404 unless DEMO_RESET=true was set on
  # purpose, and then only to an hr_admin.
  class DemoResetsController < ApplicationController
    include CompanyScoped
    include HrAdminOnly

    before_action :require_enabled!
    before_action :require_current_person!
    before_action :require_hr_admin!

    def create
      Demo::Reset.call
      cookies.delete(:keel_session)
      render_success(data: {}, message: "Demo reset to Demo Factorial.")
    end

    private

    def require_enabled!
      render_error(message: "Not found.", status: :not_found) unless Demo::Reset.enabled?
    end
  end
end
