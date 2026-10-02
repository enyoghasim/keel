module Assemble
  # Guesses the Keel roles a person holds from their job title, because a
  # roster has titles and policies point at roles (SPEC.md section 6, stage
  # 2). Deterministic, so the same CSV always builds the same company.
  # Only the leading titles qualify — "People Partner" or "Finance Analyst"
  # hold no role — since a role grants approval and admin rights.
  module RoleInference
    RULES = {
      "hr_admin" => /\A(head of people|hr (manager|admin|lead|director)|people (lead|director))\z/i,
      "finance_lead" => /\A(finance (lead|director|manager)|head of finance|cfo)\z/i,
      "it_admin" => /\A(it (admin|lead|manager)|head of it)\z/i
    }.freeze

    def self.for(title)
      RULES.filter_map { |role, pattern| role if title.to_s.strip.match?(pattern) }
    end
  end
end
