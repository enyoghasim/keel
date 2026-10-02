class AddConversationIdToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :conversation_id, :string
  end
end
