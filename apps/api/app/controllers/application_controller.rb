class ApplicationController < ActionController::API
  include ActionController::Cookies
  include Renderable

  # Where per-IP rate limits count (SPEC.md section 18's demo guard). Tests run
  # with a null cache, which would never limit, so they count in memory.
  class_attribute :rate_limit_store, default: Rails.env.test? ? ActiveSupport::Cache::MemoryStore.new : Rails.cache

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ArgumentError, with: :render_argument_error

  # `rate_limit` for the endpoints that spend model money: per client address,
  # answering in the usual envelope.
  def self.limit_per_ip(to:, within:, **options)
    rate_limit(
      to: to, within: within, store: rate_limit_store, **options,
      with: -> { render_error(message: "Too many requests from your address. Please try again later.", status: :too_many_requests) }
    )
  end

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
