module Renderable
  extend ActiveSupport::Concern

  def render_success(data: nil, message: "", meta: nil, status: :ok)
    body = { success: true, message: message }
    body[:data] = data unless data.nil?
    body[:meta] = meta unless meta.nil?
    render json: body, status: status
  end

  def render_error(message:, errors: nil, status: :unprocessable_content)
    body = { success: false, message: message }
    body[:errors] = errors unless errors.nil?
    render json: body, status: status
  end
end
