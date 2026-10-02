class Request < ApplicationRecord
  belongs_to :company
  belongs_to :requester, class_name: "Person"
  has_one :workflow_run, dependent: :destroy

  validates :kind, presence: true
end
