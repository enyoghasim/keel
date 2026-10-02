class Session < ApplicationRecord
  # Server-side revocable sessions (SPEC.md section 8's "person switcher" is
  # out; a real login replaces it). The raw token is only ever held by the
  # client, in a signed cookie; the database stores just its digest, the
  # same reasoning has_secure_password uses for passwords.
  EXPIRY = 1.week

  belongs_to :person

  def self.start!(person)
    token = SecureRandom.urlsafe_base64(32)
    session = create!(person: person, token_digest: digest(token), expires_at: EXPIRY.from_now)
    [ session, token ]
  end

  def self.authenticate(token)
    return nil if token.blank?

    find_by(token_digest: digest(token))&.then { |session| session unless session.expired? }
  end

  def self.digest(token) = Digest::SHA256.hexdigest(token)

  def expired? = expires_at.past?
end
