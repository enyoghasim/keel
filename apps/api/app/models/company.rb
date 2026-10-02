class Company < ApplicationRecord
  has_many :departments, dependent: :destroy
  has_many :people, dependent: :destroy

  validates :name, presence: true
end
