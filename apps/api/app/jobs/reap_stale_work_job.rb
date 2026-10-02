# Recurring (config/recurring.yml): fails agent runs, insight questions and
# eval runs that a dead worker left unfinished.
class ReapStaleWorkJob < ApplicationJob
  def perform = StaleWork::Reaper.call
end
