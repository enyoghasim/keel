class ApplicationController < ActionController::API
  include ActionController::Cookies
  include Renderable

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ArgumentError, with: :render_argument_error

  private

  def render_not_found(exception)
    render_error(message: exception.message, status: :not_found)
  end

  def render_argument_error(exception)
    render_error(message: exception.message, status: :unprocessable_content)
  end

  def current_session
    @current_session ||= Session.authenticate(cookies.signed[:keel_session])
  end

  def current_person
    @current_person ||= current_session&.person
  end

  def require_current_person!
    render_error(message: "Not signed in.", status: :unauthorized) unless current_person
  end
end
