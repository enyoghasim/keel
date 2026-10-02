# Streams one InsightQuery's outcome to the /insights page once InsightJob
# finishes. Sends the current state on subscribe too, in case the job won
# the race against the subscription. No auth yet, same as AssembleChannel.
class InsightChannel < ApplicationCable::Channel
  def subscribed
    insight_query = InsightQuery.find(params[:insight_query_id])
    stream_for insight_query
    transmit insight_query.as_payload
  end
end
