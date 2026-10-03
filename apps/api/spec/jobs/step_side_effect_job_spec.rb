require "rails_helper"

RSpec.describe StepSideEffectJob, type: :job do
  include ActionCable::TestHelper

  let(:company) { create(:company) }
  let(:requester) { create(:person, company: company, name: "Ngozi Okafor") }
  let(:request) { create(:request, company: company, requester: requester, kind: "leave") }
  let(:workflow) do
    create(:workflow, company: company, trigger: { "request_kind" => "leave" }, steps: [
      { "key" => "notify_hr", "type" => "notify", "title" => "Notify HR", "assignee" => "role:hr_admin",
        "integration" => { "kind" => "slack" } }
    ])
  end
  let(:workflow_run) { create(:workflow_run, request: request, workflow: workflow) }
  let(:step_run) { create(:step_run, workflow_run: workflow_run, step_key: "notify_hr", external_status: "pending") }

  it "sends the Slack message and marks the step sent" do
    allow(Slack::Notifier).to receive(:call)

    described_class.perform_now(step_run.id)

    expect(Slack::Notifier).to have_received(:call).with(company: company, text: a_string_including("Notify HR"))
    expect(step_run.reload.external_status).to eq("sent")
  end

  it "broadcasts the result" do
    allow(Slack::Notifier).to receive(:call)

    expect { described_class.perform_now(step_run.id) }
      .to have_broadcasted_to(step_run).from_channel(StepRunChannel)
      .with(hash_including("external_status" => "sent"))
  end

  it "records the failure without raising when the Slack call fails" do
    allow(Slack::Notifier).to receive(:call).and_raise(RuntimeError, "Slack webhook returned 500")

    described_class.perform_now(step_run.id)

    expect(step_run.reload).to have_attributes(external_status: "failed", external_error: "Slack webhook returned 500")
  end

  it "does nothing for a step that isn't awaiting a side effect" do
    step_run.update!(external_status: "sent")
    allow(Slack::Notifier).to receive(:call)

    described_class.perform_now(step_run.id)

    expect(Slack::Notifier).not_to have_received(:call)
  end

  it "records the returned ref (nil for Slack, which returns nothing)" do
    allow(Slack::Notifier).to receive(:call).and_return(nil)

    described_class.perform_now(step_run.id)

    expect(step_run.reload.external_ref).to be_nil
  end

  context "a task step bound to google_calendar" do
    let(:request) { create(:request, company: company, requester: requester, kind: "leave", payload: { "days" => 5 }) }
    let(:workflow) do
      create(:workflow, company: company, trigger: { "request_kind" => "leave" }, steps: [
        { "key" => "create_event", "type" => "task", "title" => "Create company calendar event", "assignee" => "role:it_admin",
          "integration" => { "kind" => "google_calendar" } }
      ])
    end
    let(:step_run) { create(:step_run, workflow_run: workflow_run, step_key: "create_event", external_status: "pending") }

    it "creates a Calendar event for the requester spanning the request's day count, and records the event id" do
      captured = {}
      allow(Calendar::EventCreator).to receive(:call) { |**kwargs| captured = kwargs; "evt_123" }

      described_class.perform_now(step_run.id)

      expect(captured[:company]).to eq(company)
      expect(captured[:summary]).to include("Create company calendar event")
      expect(captured[:attendee_person]).to eq(requester)
      expect(captured[:ends_at] - captured[:starts_at]).to be_within(1).of(5.days)
      expect(step_run.reload).to have_attributes(external_status: "sent", external_ref: "evt_123")
    end

    it "records the failure without raising when the Calendar call fails" do
      allow(Calendar::EventCreator).to receive(:call).and_raise(RuntimeError, "Google Calendar returned 500")

      described_class.perform_now(step_run.id)

      expect(step_run.reload).to have_attributes(external_status: "failed", external_error: "Google Calendar returned 500")
    end
  end
end
