# Fires the real side effect a workflow step is bound to (a Slack message,
# a Calendar event) once Workflows::Runtime has resolved it. Always a job,
# never inline in Runtime (SPEC.md section 8): Runtime's own methods are
# synchronous, called directly inside a controller action, and a flaky
# external call must never make a request submission or an approval click
# hang or 500.
class StepSideEffectJob < ApplicationJob
  def perform(step_run_id)
    @step_run = StepRun.find(step_run_id)
    return unless @step_run.external_status == "pending"

    ref = dispatch
    @step_run.update!(external_status: "sent", external_ref: ref)
  rescue StandardError => e
    Rails.logger.error("[StepSideEffectJob] #{e.class}: #{e.message}")
    @step_run.update!(external_status: "failed", external_error: e.message)
  ensure
    StepRunChannel.broadcast_to(@step_run, @step_run.as_payload) if @step_run
  end

  private

  def dispatch
    case integration_kind
    when "slack" then Slack::Notifier.call(company: company, text: message)
    when "google_calendar"
      Calendar::EventCreator.call(company: company, summary: message, attendee_person: request.requester,
        starts_at: Time.current, ends_at: Time.current + event_span)
    else raise "no side effect wired for integration kind #{integration_kind.inspect}"
    end
  end

  def step_definition
    @step_run.workflow_run.workflow.steps.find { _1["key"] == @step_run.step_key }
  end

  def integration_kind = step_definition&.dig("integration", "kind")

  def request = @step_run.workflow_run.request

  def company = request.company

  def message
    title = step_definition["title"] || @step_run.step_key
    "#{request.requester.name}'s #{request.kind} request — #{title}"
  end

  # The request payload has no explicit start/end date to build a precise
  # Calendar event from (SPEC.md's leave payload is just a day count) — a
  # "days"-long event starting now, when this task becomes active, is the
  # closest honest approximation without inventing a new payload field.
  def event_span = (request.payload["days"].presence || 1).to_i.days
end
