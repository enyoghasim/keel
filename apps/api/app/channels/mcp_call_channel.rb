# Streams one person's MCP tool calls to their Settings page as they
# arrive. No auth yet, same as the other channels.
class McpCallChannel < ApplicationCable::Channel
  def subscribed
    stream_for Person.find(params[:person_id])
  end
end
