# Streams one StepRun's external-side-effect outcome (sent/failed) once
# StepSideEffectJob finishes, same shape as RuleResolutionChannel.
class StepRunChannel < ApplicationCable::Channel
  def subscribed
    step_run = StepRun.find(params[:step_run_id])
    stream_for step_run
    transmit step_run.as_payload
  end
end
