class Person < ApplicationRecord
  # Keel has no signup flow — every Person is created by the Assemble CSV
  # import, which collects no password. Every imported person logs in with
  # this shared demo password unless one is set explicitly.
  DEMO_PASSWORD = "password"

  belongs_to :company
  belongs_to :department, optional: true
  belongs_to :manager, class_name: "Person", optional: true
  has_many :direct_reports, class_name: "Person", foreign_key: :manager_id, dependent: :nullify
  has_many :requests, foreign_key: :requester_id, inverse_of: :requester, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :mcp_calls, dependent: :destroy
  has_many :personal_access_tokens, dependent: :destroy
  has_many :insight_queries, dependent: :destroy
  has_many :eval_runs, dependent: :nullify
  has_many :agent_runs, dependent: :destroy

  has_secure_password

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { scope: :company_id }

  before_validation { self.password ||= DEMO_PASSWORD if new_record? && password_digest.blank? }

  def hr_admin?
    roles.include?("hr_admin")
  end
end
