FactoryBot.define do
  factory :personal_access_token do
    person
    name { "Claude Desktop" }
    token_digest { PersonalAccessToken.digest(SecureRandom.hex(8)) }
  end
end
