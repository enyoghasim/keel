# Thumbs up/down on an answer (SPEC.md section 9's Feedback): the rating and,
# for a thumbs-down, what was wrong. A thumbs-down also becomes a candidate
# eval case (see Agent::Feedback).
class AddFeedbackToAgentRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :agent_runs, :feedback, :string
    add_column :agent_runs, :feedback_reason, :string
    add_column :agent_runs, :feedback_note, :text
  end
end
