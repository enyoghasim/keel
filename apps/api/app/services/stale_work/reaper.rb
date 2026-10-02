module StaleWork
  # Fails work that a dead worker left pending or running forever. Every
  # LLM-backed job (AgentJob, InsightJob, EvalRunJob) skips records that
  # aren't pending and nothing retries them, so a worker that crashes — or,
  # in dev, a server restart that drops the async adapter's in-flight jobs —
  # would otherwise leave the UI spinning on a record that will never
  # finish. Deterministic: a clock and a status, no model. Each record is
  # failed with a plain message and the change is broadcast so an open page
  # updates without a refresh.
  class Reaper
    MESSAGE = "This took too long and was stopped — the worker may have restarted. Please try again.".freeze
    UNFINISHED = %w[pending running].freeze

    # How long each kind of work may sit unfinished, counted from its last
    # update: an agent run or insight question is a handful of model calls,
    # an eval run is a whole suite of them.
    TIMEOUTS = { AgentRun => 5.minutes, InsightQuery => 2.minutes, EvalRun => 15.minutes }.freeze

    # Returns how many of each it failed, e.g. { agent_runs: 1, insight_queries: 0, eval_runs: 0 }.
    def self.call = new.call

    def call
      TIMEOUTS.to_h { |model, timeout| [ model.table_name.to_sym, reap(model, timeout) ] }
    end

    private

    def reap(model, timeout)
      cutoff = timeout.ago
      model.where(status: UNFINISHED).where(updated_at: ...cutoff).to_a.count { fail!(model, _1) }
    end

    # Guarded on the status so a run that finished a moment ago isn't
    # overwritten; returns whether this call was the one that failed it.
    def fail!(model, record)
      attrs = { status: "failed", error_message: MESSAGE, updated_at: Time.current }
      attrs[:finished_at] = Time.current if record.respond_to?(:finished_at)
      return false unless model.where(id: record.id, status: UNFINISHED).update_all(attrs) == 1

      broadcast(record.reload)
      true
    end

    def broadcast(record)
      case record
      when AgentRun then AgentChannel.broadcast_to(record, { "event" => "run", "run" => record.as_payload })
      when InsightQuery then InsightChannel.broadcast_to(record, record.as_payload)
      when EvalRun then EvalChannel.broadcast_to(record, { "event" => "run", "run" => record.as_payload })
      end
    end
  end
end
