class Company < ApplicationRecord
  has_many :departments, dependent: :destroy
  has_many :people, dependent: :destroy
  has_many :workflows, dependent: :destroy
  has_many :requests, dependent: :destroy
  has_many :import_issues, dependent: :destroy
  has_many :source_documents, dependent: :destroy
  has_many :policies, dependent: :destroy
  has_many :change_proposals, dependent: :destroy
  has_many :insight_queries, dependent: :destroy
  has_many :eval_runs, dependent: :destroy
  has_one_attached :roster_csv

  validates :name, presence: true

  # The rules Rules::Engine evaluates for a request kind: active rules on
  # this company's active policies of that category.
  def active_rule_definitions(category)
    policies.where(status: "active", category: category).flat_map do |policy|
      policy.rules.where(status: "active").map(&:to_rule_definition)
    end
  end
end
