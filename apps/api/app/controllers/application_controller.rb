class ApplicationController < ActionController::API
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
end
