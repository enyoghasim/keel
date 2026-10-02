class ImportIssue < ApplicationRecord
  belongs_to :company

  validates :row_number, :field, :message, presence: true
end
