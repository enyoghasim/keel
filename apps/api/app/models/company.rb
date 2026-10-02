class Company < ApplicationRecord
  has_many :departments, dependent: :destroy
  has_many :people, dependent: :destroy
  has_many :workflows, dependent: :destroy
  has_many :requests, dependent: :destroy

  validates :name, presence: true
end
