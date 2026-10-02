# A versioned prompt template (SPEC.md sections 4 and 12). Prompts live in
# the database so an eval run can score a challenger against the active
# version and a human can promote the better one, without a deploy.
# Templates use {{placeholder}} slots filled by #render.
class PromptVersion < ApplicationRecord
  has_many :eval_runs, dependent: :nullify

  validates :key, :template, presence: true
  validates :version, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :key }

  def self.active_for(key) = find_by(key: key, active: true)

  # Makes this the only active version for its key, in one transaction (a
  # partial unique index guarantees there is never more than one).
  def promote!
    transaction do
      self.class.where(key: key, active: true).where.not(id: id).update_all(active: false)
      update!(active: true)
    end
  end

  def render(**values)
    template.gsub(/\{\{(\w+)\}\}/) { values.fetch(Regexp.last_match(1).to_sym) { raise KeyError, "missing placeholder #{Regexp.last_match(1)}" }.to_s }
  end

  FIELDS = %i[id key version model active notes created_at].freeze
end
