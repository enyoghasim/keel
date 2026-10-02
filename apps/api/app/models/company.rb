class Company < ApplicationRecord
  has_many :departments, dependent: :destroy
  has_many :people, dependent: :destroy
  has_many :workflows, dependent: :destroy
  has_many :requests, dependent: :destroy
  has_many :import_issues, dependent: :destroy
  has_many :source_documents, dependent: :destroy
  has_many :policies, dependent: :destroy
  has_one_attached :roster_csv

  validates :name, presence: true
end
