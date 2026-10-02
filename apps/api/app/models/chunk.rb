class Chunk < ApplicationRecord
  belongs_to :source_document
  has_neighbors :embedding

  validates :page, :position, :text, presence: true
end
