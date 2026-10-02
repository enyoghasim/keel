class SourceDocument < ApplicationRecord
  belongs_to :company
  has_many :chunks, dependent: :destroy
  has_one_attached :file

  validates :filename, :kind, presence: true
end
