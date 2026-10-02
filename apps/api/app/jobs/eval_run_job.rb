# Runs one EvalRun with Evals::Runner (SPEC.md section 12) and streams
# its progress on EvalChannel: each case's result as it's scored, and the
# run itself when it starts and finishes.
class EvalRunJob < ApplicationJob
  def perform(eval_run_id)
    eval_run = EvalRun.find(eval_run_id)
    return unless eval_run.status == "pending"

    broadcast_run(eval_run.tap { _1.update!(status: "running") })
    Evals::Runner.call(eval_run) do |result, done, total|
      EvalChannel.broadcast_to(eval_run, { "event" => "result", "result" => result.as_payload, "done" => done, "total" => total })
    end
  rescue StandardError => e
    Rails.logger.error("[EvalRunJob] #{e.class}: #{e.message}")
    eval_run&.update!(status: "failed", finished_at: Time.current, error_message: Llm::Failure.message_for(e, fallback: "#{e.class}: #{e.message}"))
  ensure
    broadcast_run(eval_run) if eval_run
  end

  private

  def broadcast_run(eval_run)
    EvalChannel.broadcast_to(eval_run, { "event" => "run", "run" => eval_run.reload.as_payload })
  end
end
