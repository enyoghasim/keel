# A bearer token a person creates to let an external MCP client (Claude
# Desktop, ...) act as them (SPEC.md section 13). The raw token is shown
# once, at creation; the database holds only its digest, and a token can be
# revoked. Production would use OAuth, which MCP supports.
class PersonalAccessToken < ApplicationRecord
  PREFIX = "keel_pat_".freeze

  belongs_to :person

  validates :name, :token_digest, presence: true

  scope :active, -> { where(revoked_at: nil) }

  def self.issue!(person, name:)
    raw = "#{PREFIX}#{SecureRandom.urlsafe_base64(32)}"
    [ create!(person: person, name: name, token_digest: digest(raw)), raw ]
  end

  def self.authenticate(raw)
    return nil if raw.blank?

    token = active.find_by(token_digest: digest(raw))
    token&.tap { _1.update_column(:last_used_at, Time.current) }
  end

  def self.digest(raw) = Digest::SHA256.hexdigest(raw)

  FIELDS = %i[id name last_used_at revoked_at created_at].freeze
end
