class Person < ApplicationRecord
  belongs_to :company
  belongs_to :department, optional: true
  belongs_to :manager, class_name: "Person", optional: true
  has_many :direct_reports, class_name: "Person", foreign_key: :manager_id, dependent: :nullify
  has_many :requests, foreign_key: :requester_id, inverse_of: :requester, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { scope: :company_id }
end
