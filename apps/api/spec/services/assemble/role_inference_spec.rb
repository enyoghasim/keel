require "rails_helper"

RSpec.describe Assemble::RoleInference do
  # A roster has job titles, not Keel roles, but policies and workflows point
  # at roles (role:finance_lead), so an imported company needs somebody to
  # hold them. Plain title matching, no model: a wrong guess is visible on
  # the graph and one proposal away from fixed.
  {
    "Head of People" => %w[hr_admin],
    "HR Manager" => %w[hr_admin],
    "People Lead" => %w[hr_admin],
    "Finance Lead" => %w[finance_lead],
    "Head of Finance" => %w[finance_lead],
    "CFO" => %w[finance_lead],
    "IT Admin" => %w[it_admin],
    "Head of IT" => %w[it_admin],
    "Account Executive" => [],
    "People Partner" => [],
    "Finance Analyst" => [],
    "IT Support Specialist" => [],
    "Whitelist Manager" => [],
    nil => []
  }.each do |title, roles|
    it "gives #{title.inspect} #{roles.empty? ? 'no roles' : roles.join(', ')}" do
      expect(described_class.for(title)).to eq(roles)
    end
  end
end
