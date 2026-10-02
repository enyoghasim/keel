# Streams AssembleJob's progress events (SPEC.md section 6's event format)
# to the frontend for a single company's import. No auth yet — every
# company's events live on their own stream regardless.
class AssembleChannel < ApplicationCable::Channel
  def subscribed
    stream_for Company.find(params[:company_id])
  end
end
