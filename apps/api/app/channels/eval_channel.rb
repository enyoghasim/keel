# Streams one EvalRun's progress to the Trust page while EvalRunJob runs
# it. Sends the run's current state on subscribe, so a page that
# subscribes late still knows where the run is. No auth yet, same as
# AssembleChannel and InsightChannel.
class EvalChannel < ApplicationCable::Channel
  def subscribed
    eval_run = EvalRun.find(params[:eval_run_id])
    stream_for eval_run
    transmit({ "event" => "run", "run" => eval_run.as_payload })
  end
end
