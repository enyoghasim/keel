# Groups agent runs into conversations (SPEC.md section 9): each message is
# still its own run with its own trace, but runs sharing a conversation_id
# are replayed to the model as earlier turns. Existing runs each become a
# one-message conversation.
class AddConversationIdToAgentRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :agent_runs, :conversation_id, :uuid, null: false, default: -> { "gen_random_uuid()" }
    add_index :agent_runs, %i[person_id conversation_id]
  end
end
