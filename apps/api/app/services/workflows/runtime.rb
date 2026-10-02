module Workflows
  # Moves a request from submission to done (SPEC.md section 8). No LLM
  # involved: the engine decides the outcome and who approves, the runtime
  # just sequences steps and resolves each one's reference at the moment it
  # becomes active, so a mid-flight reorg routes the next step correctly.
  class Runtime
    TERMINAL_STATUS = { "auto_approve" => "approved", "reject" => "rejected", "blocked" => "blocked" }.freeze

    DryRunResult = Data.define(:outcome, :matched_rule_keys, :errors, :steps)
    StepPreview = Data.define(:step_key, :type, :reference, :resolved_person_id, :matched)

    def initialize(snapshot)
      @snapshot = snapshot
      @engine = Rules::Engine.new(snapshot)
      @resolver = Org::Resolver.new(snapshot)
    end

    def start(request, rules:)
      decision = @engine.evaluate(request_input(request), rules)
      request.update!(decision: decision.outcome, matched_rule_ids: decision.rule_keys)

      if TERMINAL_STATUS.key?(decision.outcome)
        workflow_run = WorkflowRun.create!(request: request, workflow: nil, status: "done")
        StepRun.create!(workflow_run: workflow_run, step_key: "system", status: "done", acted_at: Time.current)
        request.update!(status: TERMINAL_STATUS.fetch(decision.outcome))
        return request
      end

      workflow = find_workflow(request)
      raise ArgumentError, "no active workflow for request kind '#{request.kind}'" if workflow.nil?

      workflow_run = WorkflowRun.create!(request: request, workflow: workflow, status: "in_progress")
      create_step_runs(workflow_run, workflow, decision, request)
      advance!(workflow_run)
      request
    end

    def act(step_run, action:, reason: nil)
      case action.to_s
      when "approve", "complete"
        step_run.update!(status: "done", acted_at: Time.current)
        advance!(step_run.workflow_run)
      when "reject"
        step_run.update!(status: "rejected", acted_at: Time.current)
        step_run.workflow_run.step_runs.where(status: "pending").update_all(status: "cancelled")
        step_run.workflow_run.update!(status: "rejected")
        step_run.workflow_run.request.update!(status: "rejected")
      when "override"
        request = step_run.workflow_run.request
        step_run.update!(overridden: true, override_reason: reason, acted_at: Time.current)
        request.update!(status: request.decision == "auto_approve" ? "rejected" : "approved")
      else
        raise ArgumentError, "unknown action #{action}"
      end

      step_run
    end

    # "Test run" (SPEC.md section 8): previews how a workflow would resolve
    # right now, with nothing saved. A terminal decision (auto_approve,
    # reject, blocked) short-circuits just like #start. Otherwise every step
    # is resolved up front rather than one at a time — unlike a real run,
    # nothing here can change the snapshot between steps, so resolving them
    # all now gives the same answer as resolving each as it becomes active.
    def dry_run(workflow, requester_id:, payload:, rules:)
      decision = @engine.evaluate(Rules::RequestInput.new(requester_id: requester_id, payload: payload), rules)

      if TERMINAL_STATUS.key?(decision.outcome)
        return DryRunResult.new(decision.outcome, decision.rule_keys, decision.errors,
          [ StepPreview.new("system", "system", nil, nil, true) ])
      end

      ctx = Rules::Context.build(Rules::RequestInput.new(requester_id: requester_id, payload: payload), @snapshot)
      steps = workflow.steps.flat_map { preview_step(_1, ctx, decision, requester_id) }

      DryRunResult.new(decision.outcome, decision.rule_keys, decision.errors, steps)
    end

    private

    def preview_step(step, ctx, decision, requester_id)
      matched = step["when"].nil? || Rules::Condition.match?(step["when"], ctx)

      if step["type"] == "approval"
        return [ StepPreview.new(step["key"], "approval", nil, nil, false) ] unless matched

        decision.approvers.map { StepPreview.new(step["key"], "approval", "person:#{_1}", _1, true) }
      else
        resolved_id = matched ? @resolver.resolve(step["assignee"], requester_id: requester_id).person_ids.first : nil
        [ StepPreview.new(step["key"], step["type"], step["assignee"], resolved_id, matched) ]
      end
    end

    def request_input(request) = Rules::RequestInput.new(requester_id: request.requester_id, payload: request.payload)

    def find_workflow(request)
      request.company.workflows.where(status: "active").detect { _1.trigger["request_kind"] == request.kind }
    end

    def create_step_runs(workflow_run, workflow, decision, request)
      ctx = Rules::Context.build(request_input(request), @snapshot)

      workflow.steps.each do |step|
        next if step["when"] && !Rules::Condition.match?(step["when"], ctx)

        if step["type"] == "approval"
          decision.approvers.each do |person_id|
            StepRun.create!(workflow_run: workflow_run, step_key: step["key"], reference: "person:#{person_id}", status: "pending")
          end
        else
          StepRun.create!(workflow_run: workflow_run, step_key: step["key"], reference: step["assignee"], status: "pending")
        end
      end
    end

    def advance!(workflow_run)
      loop do
        next_step = workflow_run.step_runs.where(status: "pending").order(:id).first
        return finish!(workflow_run) if next_step.nil?

        resolve!(next_step, workflow_run.request) if next_step.resolved_person_id.nil?

        step_definition = workflow_run.workflow.steps.find { _1["key"] == next_step.step_key }
        if step_definition&.fetch("type") == "notify"
          next_step.update!(status: "done", acted_at: Time.current)
          next
        end

        return
      end
    end

    def resolve!(step_run, request)
      result = @resolver.resolve(step_run.reference, requester_id: request.requester_id)
      step_run.update!(resolved_person_id: result.person_ids.first)
    end

    def finish!(workflow_run)
      workflow_run.update!(status: "done")
      workflow_run.request.update!(status: "approved")
    end
  end
end
