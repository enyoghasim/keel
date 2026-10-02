module AuthHelpers
  # Signs in via the real session endpoint (as opposed to stubbing
  # current_person) so request specs exercise the actual cookie flow.
  def sign_in(person)
    post "/api/companies/#{person.company_id}/session",
      params: { email: person.email, password: Person::DEMO_PASSWORD }, as: :json
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
