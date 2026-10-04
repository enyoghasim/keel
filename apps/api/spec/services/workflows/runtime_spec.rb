require "rails_helper"

RSpec.describe Workflows::Runtime do
  include ActiveJob::TestHelper

  # Mirrors SPEC.md section 8's request lifecycle: one example per real-world
  # path through start/advance/act, not per method.
  def runtime_for(company) = described_class.new(Org::GraphSnapshot.load(company))

  def big_expense_rule(approvers)
    Rules::RuleDefinition.new(
      key: "big_expense", priority: 1,
      conditions: { "field" => "payload.amount_eur", "op" => "gt", "value" => 500 },
      actions: { "decision" => "require_approval", "approvers" => approvers },
    )
  end

  it "auto-approves and records a single system step, with no workflow involved" do
    company = create(:company)
    requester = create(:person, company: company)
    request = create(:request, company: company, requester: requester, payload: { "amount_eur" => 100 })
    small_expense_rule = Rules::RuleDefinition.new(
      key: "small_expense", priority: 1,
      conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 },
      actions: { "decision" => "auto_approve" },
    )

    result = runtime_for(company).start(request, rules: [ small_expense_rule ])

    expect(result.status).to eq("approved")
    expect(result.decision).to eq("auto_approve")
    step_runs = result.workflow_run.step_runs
    expect(step_runs.size).to eq(1)
    expect(step_runs.first).to have_attributes(step_key: "system", status: "done")
  end

  it "rejects and records a single system step, with no workflow involved" do
    company = create(:company)
    requester = create(:person, company: company)
    request = create(:request, company: company, requester: requester, kind: "leave", payload: { "days" => 3, "notice_days" => 1 })
    notice_period_rule = Rules::RuleDefinition.new(
      key: "notice_period", priority: 1,
      conditions: { "field" => "payload.notice_days", "op" => "lt", "value" => 14 },
      actions: { "decision" => "reject", "reason" => "insufficient notice" },
    )

    result = runtime_for(company).start(request, rules: [ notice_period_rule ])

    expect(result.status).to eq("rejected")
    expect(result.workflow_run.step_runs.sole).to have_attributes(step_key: "system", status: "done")
  end

  it "still runs a terminal auto-approved decision's non-approval steps against a matching workflow, skipping the approval step entirely" do
    company = create(:company)
    it_admin = create(:person, :it_admin, company: company)
    requester = create(:person, company: company)
    request = create(:request, company: company, requester: requester, payload: { "amount_eur" => 100 })
    create(:workflow, company: company, trigger: { "request_kind" => "expense" }, steps: [
      { "key" => "approval", "type" => "approval" },
      { "key" => "log", "type" => "task", "assignee" => "role:it_admin" }
    ])
    small_expense_rule = Rules::RuleDefinition.new(
      key: "small_expense", priority: 1,
      conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 },
      actions: { "decision" => "auto_approve" },
    )

    result = runtime_for(company).start(request, rules: [ small_expense_rule ])

    expect(result.status).to eq("approved")
    steps = result.workflow_run.step_runs
    expect(steps.pluck(:step_key)).to eq([ "log" ])
    expect(steps.first).to have_attributes(resolved_person_id: it_admin.id, status: "pending")
  end

  it "still runs a terminal rejected decision's non-approval steps, and finishing them doesn't flip the request back to approved" do
    company = create(:company)
    hr_admin = create(:person, :hr_admin, company: company)
    requester = create(:person, company: company)
    request = create(:request, company: company, requester: requester, kind: "leave", payload: { "days" => 3, "notice_days" => 1 })
    create(:workflow, company: company, trigger: { "request_kind" => "leave" }, steps: [
      { "key" => "approval", "type" => "approval" },
      { "key" => "notify_hr", "type" => "notify", "assignee" => "role:hr_admin" }
    ])
    notice_period_rule = Rules::RuleDefinition.new(
      key: "notice_period", priority: 1,
      conditions: { "field" => "payload.notice_days", "op" => "lt", "value" => 14 },
      actions: { "decision" => "reject", "reason" => "insufficient notice" },
    )

    result = runtime_for(company).start(request, rules: [ notice_period_rule ])

    expect(result.status).to eq("rejected")
    notify_step = result.workflow_run.step_runs.sole
    expect(notify_step).to have_attributes(step_key: "notify_hr", status: "done", resolved_person_id: hr_admin.id)
    expect(result.workflow_run.reload.status).to eq("done")
    expect(request.reload.status).to eq("rejected")
  end

  it "falls back to a single system step when a terminal decision's matching workflow has no applicable non-approval steps" do
    company = create(:company)
    requester = create(:person, company: company)
    request = create(:request, company: company, requester: requester, payload: { "amount_eur" => 100 })
    create(:workflow, company: company, trigger: { "request_kind" => "expense" }, steps: [
      { "key" => "approval", "type" => "approval" },
      { "key" => "log", "type" => "task", "assignee" => "role:it_admin",
        "when" => { "field" => "payload.amount_eur", "op" => "gt", "value" => 100_000 } }
    ])
    small_expense_rule = Rules::RuleDefinition.new(
      key: "small_expense", priority: 1,
      conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 },
      actions: { "decision" => "auto_approve" },
    )

    result = runtime_for(company).start(request, rules: [ small_expense_rule ])

    expect(result.status).to eq("approved")
    expect(result.workflow_run.step_runs.sole).to have_attributes(step_key: "system", status: "done")
    expect(result.workflow_run.reload.status).to eq("done")
  end

  it "still bypasses the workflow entirely for a blocked decision, even when one matches" do
    company = create(:company)
    requester = create(:person, :without_manager, company: company)
    request = create(:request, company: company, requester: requester, payload: { "amount_eur" => 900 })
    create(:workflow, company: company, trigger: { "request_kind" => "expense" }, steps: [
      { "key" => "approval", "type" => "approval" },
      { "key" => "log", "type" => "task", "assignee" => "role:it_admin" }
    ])

    result = runtime_for(company).start(request, rules: [ big_expense_rule([ "manager_of(requester)" ]) ])

    expect(result.status).to eq("blocked")
    expect(result.workflow_run.workflow).to be_nil
    expect(result.workflow_run.step_runs.sole).to have_attributes(step_key: "system", status: "done")
  end

  it "raises when a request needs approval but no active workflow matches its kind" do
    company = create(:company)
    manager = create(:person, company: company)
    requester = create(:person, company: company, manager: manager)
    request = create(:request, company: company, requester: requester, kind: "expense", payload: { "amount_eur" => 900 })

    expect { runtime_for(company).start(request, rules: [ big_expense_rule([ "manager_of(requester)" ]) ]) }
      .to raise_error(ArgumentError, /no active workflow/)
  end

  it "walks a multi-approver chain one step at a time, finishing once every step is done" do
    company = create(:company)
    manager = create(:person, company: company)
    finance_lead = create(:person, :finance_lead, company: company)
    requester = create(:person, company: company, manager: manager)
    request = create(:request, company: company, requester: requester, kind: "expense", payload: { "amount_eur" => 900 })
    create(:workflow, company: company, trigger: { "request_kind" => "expense" }, steps: [ { "key" => "approval", "type" => "approval" } ])

    runtime = runtime_for(company)
    result = runtime.start(request, rules: [ big_expense_rule([ "manager_of(requester)", "role:finance_lead" ]) ])
    steps = result.workflow_run.step_runs.order(:id).to_a

    expect(steps.size).to eq(2)
    expect(steps[0]).to have_attributes(resolved_person_id: manager.id, status: "pending")
    expect(steps[1].resolved_person_id).to be_nil

    runtime.act(steps[0], action: "approve")
    expect(steps[1].reload).to have_attributes(resolved_person_id: finance_lead.id, status: "pending")
    expect(request.reload.status).to eq("pending")

    runtime.act(steps[1], action: "approve")
    expect(request.reload.status).to eq("approved")
    expect(result.workflow_run.reload.status).to eq("done")
  end

  it "fires a notify step immediately once resolved, then waits on the task step behind it" do
    company = create(:company)
    manager = create(:person, company: company)
    finance_lead = create(:person, :finance_lead, company: company)
    it_admin = create(:person, :it_admin, company: company)
    requester = create(:person, company: company, manager: manager)
    request = create(:request, company: company, requester: requester, kind: "equipment", payload: { "amount_eur" => 2000 })
    create(:workflow, company: company, trigger: { "request_kind" => "equipment" }, steps: [
      { "key" => "manager", "type" => "approval" },
      { "key" => "finance", "type" => "notify", "assignee" => "role:finance_lead",
        "when" => { "field" => "payload.amount_eur", "op" => "gt", "value" => 1500 } },
      { "key" => "it", "type" => "task", "assignee" => "role:it_admin" }
    ])

    runtime = runtime_for(company)
    result = runtime.start(request, rules: [ big_expense_rule([ "manager_of(requester)" ]) ])
    manager_step, finance_step, it_step = result.workflow_run.step_runs.order(:id).to_a

    runtime.act(manager_step, action: "approve")

    expect(finance_step.reload).to have_attributes(resolved_person_id: finance_lead.id, status: "done")
    expect(it_step.reload).to have_attributes(resolved_person_id: it_admin.id, status: "pending")
    expect(request.reload.status).to eq("pending")

    runtime.act(it_step, action: "complete")
    expect(request.reload.status).to eq("approved")
  end

  it "enqueues the side effect job once a notify step bound to an integration fires, leaving an unbound one alone" do
    company = create(:company)
    manager = create(:person, company: company)
    requester = create(:person, company: company, manager: manager)
    request = create(:request, company: company, requester: requester, kind: "equipment", payload: { "amount_eur" => 2000 })
    create(:workflow, company: company, trigger: { "request_kind" => "equipment" }, steps: [
      { "key" => "manager", "type" => "approval" },
      { "key" => "finance", "type" => "notify", "assignee" => "role:finance_lead", "integration" => { "kind" => "slack" } },
      { "key" => "hr", "type" => "notify", "assignee" => "role:hr_admin" }
    ])
    create(:person, :finance_lead, company: company)
    runtime = runtime_for(company)
    result = runtime.start(request, rules: [ big_expense_rule([ "manager_of(requester)" ]) ])
    manager_step = result.workflow_run.step_runs.order(:id).first

    expect { runtime.act(manager_step, action: "approve") }.to have_enqueued_job(StepSideEffectJob)

    finance_step = result.workflow_run.step_runs.find_by(step_key: "finance")
    hr_step = result.workflow_run.step_runs.find_by(step_key: "hr")
    expect(finance_step).to have_attributes(status: "done", external_status: "pending")
    expect(hr_step).to have_attributes(status: "done", external_status: nil)
  end

  it "enqueues the side effect job for a task step bound to an integration once it becomes active, not before the approval ahead of it, and not twice" do
    company = create(:company)
    manager = create(:person, company: company)
    create(:person, :it_admin, company: company)
    requester = create(:person, company: company, manager: manager)
    request = create(:request, company: company, requester: requester, kind: "equipment", payload: { "amount_eur" => 900 })
    create(:workflow, company: company, trigger: { "request_kind" => "equipment" }, steps: [
      { "key" => "manager", "type" => "approval" },
      { "key" => "it", "type" => "task", "assignee" => "role:it_admin", "integration" => { "kind" => "google_calendar" } }
    ])
    runtime = runtime_for(company)

    result = nil
    expect { result = runtime.start(request, rules: [ big_expense_rule([ "manager_of(requester)" ]) ]) }
      .not_to have_enqueued_job(StepSideEffectJob)

    manager_step = result.workflow_run.step_runs.find_by(step_key: "manager")
    it_step = result.workflow_run.step_runs.find_by(step_key: "it")
    expect(it_step).to have_attributes(status: "pending", external_status: nil)

    expect { runtime.act(manager_step, action: "approve") }.to have_enqueued_job(StepSideEffectJob).with(it_step.id).exactly(1).times
    expect(it_step.reload).to have_attributes(status: "pending", external_status: "pending")
  end

  it "does not create a step run for a notify step whose condition doesn't match" do
    company = create(:company)
    manager = create(:person, company: company)
    requester = create(:person, company: company, manager: manager)
    request = create(:request, company: company, requester: requester, kind: "equipment", payload: { "amount_eur" => 600 })
    create(:workflow, company: company, trigger: { "request_kind" => "equipment" }, steps: [
      { "key" => "manager", "type" => "approval" },
      { "key" => "finance", "type" => "notify", "assignee" => "role:finance_lead",
        "when" => { "field" => "payload.amount_eur", "op" => "gt", "value" => 1500 } }
    ])

    result = runtime_for(company).start(request, rules: [ big_expense_rule([ "manager_of(requester)" ]) ])

    expect(result.workflow_run.step_runs.pluck(:step_key)).to eq([ "manager" ])
  end

  it "rejects the request and cancels every remaining step when an approval step is rejected" do
    company = create(:company)
    manager = create(:person, company: company)
    finance_lead = create(:person, :finance_lead, company: company)
    requester = create(:person, company: company, manager: manager)
    request = create(:request, company: company, requester: requester, kind: "equipment", payload: { "amount_eur" => 900 })
    create(:workflow, company: company, trigger: { "request_kind" => "equipment" }, steps: [
      { "key" => "approval", "type" => "approval" },
      { "key" => "it", "type" => "task", "assignee" => "role:it_admin" }
    ])

    runtime = runtime_for(company)
    result = runtime.start(request, rules: [ big_expense_rule([ "manager_of(requester)", "role:finance_lead" ]) ])
    manager_step, finance_step, it_step = result.workflow_run.step_runs.order(:id).to_a

    runtime.act(manager_step, action: "reject")

    expect(request.reload.status).to eq("rejected")
    expect(result.workflow_run.reload.status).to eq("rejected")
    expect(finance_step.reload.status).to eq("cancelled")
    expect(it_step.reload.status).to eq("cancelled")
  end

  it "lets an approver override an auto-approved decision, with a reason" do
    company = create(:company)
    requester = create(:person, company: company)
    request = create(:request, company: company, requester: requester, payload: { "amount_eur" => 100 })
    small_expense_rule = Rules::RuleDefinition.new(
      key: "small_expense", priority: 1,
      conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 },
      actions: { "decision" => "auto_approve" },
    )
    runtime = runtime_for(company)
    result = runtime.start(request, rules: [ small_expense_rule ])
    system_step = result.workflow_run.step_runs.sole

    runtime.act(system_step, action: "override", reason: "Policy exception approved by HR")

    expect(system_step.reload).to have_attributes(overridden: true, override_reason: "Policy exception approved by HR")
    expect(request.reload.status).to eq("rejected")
  end

  describe "#dry_run" do
    def small_expense_rule
      Rules::RuleDefinition.new(
        key: "small_expense", priority: 1,
        conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 },
        actions: { "decision" => "auto_approve" },
      )
    end

    it "previews a single system step for a terminal decision, without persisting anything" do
      company = create(:company)
      requester = create(:person, company: company)

      result = runtime_for(company).dry_run(nil, requester_id: requester.id, payload: { "amount_eur" => 100 }, rules: [ small_expense_rule ])

      expect(result.outcome).to eq("auto_approve")
      expect(result.steps).to eq([ Workflows::Runtime::StepPreview.new("system", "system", nil, nil, true) ])
      expect(WorkflowRun.count).to eq(0)
      expect(StepRun.count).to eq(0)
    end

    it "previews one entry per approver in a multi-approver chain, all resolved at once" do
      company = create(:company)
      manager = create(:person, company: company)
      finance_lead = create(:person, :finance_lead, company: company)
      requester = create(:person, company: company, manager: manager)
      workflow = create(:workflow, company: company, steps: [ { "key" => "approval", "type" => "approval" } ])

      result = runtime_for(company).dry_run(
        workflow, requester_id: requester.id, payload: { "amount_eur" => 900 },
        rules: [ big_expense_rule([ "manager_of(requester)", "role:finance_lead" ]) ]
      )

      expect(result.outcome).to eq("require_approval")
      expect(result.steps).to eq([
        Workflows::Runtime::StepPreview.new("approval", "approval", "person:#{manager.id}", manager.id, true),
        Workflows::Runtime::StepPreview.new("approval", "approval", "person:#{finance_lead.id}", finance_lead.id, true)
      ])
      expect(WorkflowRun.count).to eq(0)
    end

    it "resolves a notify step's assignee and marks a step whose condition doesn't match" do
      company = create(:company)
      manager = create(:person, company: company)
      finance_lead = create(:person, :finance_lead, company: company)
      requester = create(:person, company: company, manager: manager)
      workflow = create(:workflow, company: company, steps: [
        { "key" => "manager", "type" => "approval" },
        { "key" => "finance", "type" => "notify", "assignee" => "role:finance_lead",
          "when" => { "field" => "payload.amount_eur", "op" => "gt", "value" => 1500 } }
      ])

      result = runtime_for(company).dry_run(
        workflow, requester_id: requester.id, payload: { "amount_eur" => 900 },
        rules: [ big_expense_rule([ "manager_of(requester)" ]) ]
      )

      expect(result.steps).to eq([
        Workflows::Runtime::StepPreview.new("manager", "approval", "person:#{manager.id}", manager.id, true),
        Workflows::Runtime::StepPreview.new("finance", "notify", "role:finance_lead", nil, false)
      ])
    end

    it "surfaces resolver errors (self-approval, unresolved reference) without raising" do
      company = create(:company)
      requester = create(:person, :without_manager, company: company)
      workflow = create(:workflow, company: company, steps: [ { "key" => "approval", "type" => "approval" } ])

      result = runtime_for(company).dry_run(
        workflow, requester_id: requester.id, payload: { "amount_eur" => 900 },
        rules: [ big_expense_rule([ "manager_of(requester)" ]) ]
      )

      expect(result.outcome).to eq("blocked")
      expect(result.errors).to eq([ "manager_of(requester) resolved to nobody" ])
      expect(result.steps).to eq([ Workflows::Runtime::StepPreview.new("system", "system", nil, nil, true) ])
    end
  end
end
