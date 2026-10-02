# The role check for endpoints only an hr_admin may use, to follow
# `before_action :require_current_person!` (401 when not signed in, then 403).
module HrAdminOnly
  extend ActiveSupport::Concern

  private

  def require_hr_admin!
    return if performed? || current_person.hr_admin?

    render_error(message: "Only an hr_admin can do that.", status: :forbidden)
  end
end
