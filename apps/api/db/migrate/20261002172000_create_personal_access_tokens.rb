# Per-person tokens for the MCP endpoint (SPEC.md section 13): the raw token
# is shown once at creation and only its SHA-256 digest is stored, like
# Session.
class CreatePersonalAccessTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :personal_access_tokens do |t|
      t.references :person, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token_digest, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :personal_access_tokens, :token_digest, unique: true
  end
end
