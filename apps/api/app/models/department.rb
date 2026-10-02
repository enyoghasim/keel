class Department < ApplicationRecord
  belongs_to :company
  belongs_to :head, class_name: "Person", optional: true
  has_many :people, dependent: :nullify

  validates :name, presence: true
end
