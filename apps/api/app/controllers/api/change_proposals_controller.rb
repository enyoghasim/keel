module Api
  # The other half of AGENTS.md rule 2: every org/rule/workflow change
  # becomes a ChangeProposal with a computed impact report, and only a
  # human decision via #approve or #reject makes it real (SPEC.md section
  # 10). Only the "org" kind is wired up end to end for now — "rule" and
  # "workflow" diffs need their own impact pipeline (Impact::Backtester for
  # rules; workflows have no analyzer yet) and are deferred rather than
  # guessed at.
  class ChangeProposalsController < ApplicationController
    include CompanyScoped

    FIELDS = %i[id company_id kind title diff impact proposed_by agent_run_id status decided_by_id decided_at created_at].freeze
    SUPPORTED_KINDS = %w[org].freeze
    APPROVABLE_KINDS = %w[org rule].freeze

    before_action :set_change_proposal, only: %i[show approve reject]
    before_action :require_current_person!, only: %i[approve reject]
    before_action :require_hr_admin!, only: %i[approve reject]

    def index
      scope = @company.change_proposals
      scope = scope.where(status: params[:status]) if params[:status].present?
      render_success(data: scope.order(created_at: :desc).map { serialize(_1) })
    end

    def show
      render_success(data: serialize(@change_proposal))
    end

    def create
      return render_error(message: "kind is required") if params[:kind].blank?
      return render_error(message: "title is required") if params[:title].blank?
      return render_error(message: "diff is required") if params[:diff].blank?
      unless SUPPORTED_KINDS.include?(params[:kind])
        return render_error(message: "impact analysis for kind '#{params[:kind]}' is not implemented yet")
      end

      diff = change_proposal_params[:diff]
      impact = Impact::OrgImpact.call(company: @company, diff: diff)

      change_proposal = @company.change_proposals.create!(
        kind: params[:kind], title: params[:title], diff: diff,
        impact: impact, proposed_by: params[:proposed_by].presence || "user", status: "pending"
      )

      render_success(data: serialize(change_proposal), message: "Change proposal created.", status: :created)
    rescue ActiveRecord::RecordInvalid => e
      render_error(message: e.message, errors: e.record.errors.full_messages)
    end

    def approve
      return render_error(message: "this proposal has already been decided") unless @change_proposal.status == "pending"
      unless APPROVABLE_KINDS.include?(@change_proposal.kind)
        return render_error(message: "approving a '#{@change_proposal.kind}' proposal is not implemented yet")
      end
      return approve_rule_proposal if @change_proposal.kind == "rule"

      approve_anyway = ActiveModel::Type::Boolean.new.cast(params[:approve_anyway])
      reason = params[:reason]
      return render_error(message: "a reason is required to approve anyway") if approve_anyway && reason.blank?

      impact = Impact::OrgImpact.call(company: @company, diff: @change_proposal.diff)
      current_broken = impact["broken"].size
      original_broken = @change_proposal.impact["broken"]&.size || 0

      if current_broken > original_broken && !approve_anyway
        return render_error(
          message: "impact has gotten worse since this proposal was made " \
                    "(#{current_broken} broken now vs #{original_broken} then) — " \
                    "pass approve_anyway: true with a reason to proceed anyway",
          errors: impact
        )
      end

      ActiveRecord::Base.transaction do
        @change_proposal.apply_org_diff!(@company)
        updated_impact = impact.dup
        updated_impact["override_reason"] = reason if approve_anyway
        @change_proposal.update!(
          status: "approved", impact: updated_impact,
          decided_by_id: current_person.id, decided_at: Time.current
        )
      end

      render_success(data: serialize(@change_proposal), message: "Change proposal approved.")
    end

    def reject
      return render_error(message: "this proposal has already been decided") unless @change_proposal.status == "pending"

      reason = params[:reason].to_s.strip
      impact = reason.empty? ? @change_proposal.impact : @change_proposal.impact.merge("rejection_reason" => reason)
      @change_proposal.update!(status: "rejected", impact: impact, decided_by_id: current_person.id, decided_at: Time.current)
      candidate_case_from_rejection(reason)
      render_success(data: serialize(@change_proposal), message: "Change proposal rejected.")
    end

    private

    # Only a human with the authority to change the org or its policies may
    # decide a proposal (AGENTS.md rule 2: a human approves).
    def require_hr_admin!
      return if performed? || current_person.hr_admin?

      render_error(message: "Only an hr_admin can approve or reject a proposal.", status: :forbidden)
    end

    # SPEC.md section 10: a rejection with a reason on something the agent
    # proposed becomes a candidate case for the agent suite.
    def candidate_case_from_rejection(reason)
      agent_run = @change_proposal.agent_run
      return if reason.empty? || @change_proposal.proposed_by != "agent" || agent_run.nil?

      Evals::CandidateCase.upsert(
        agent_run, key: "rejected_proposal_#{@change_proposal.id}", notes: "Proposal rejected: #{reason}",
        extra_input: { "proposal" => @change_proposal.as_json(only: %i[id kind title diff]) }
      )
    end

    # Rule proposals are replayed against history, not the org graph: the
    # backtest is re-run so the stored impact is what was true at decision
    # time, and the diff is refused if the policy moved underneath it.
    def approve_rule_proposal
      policy = @company.policies.find(@change_proposal.diff["policy_id"])

      impact = Impact::RuleImpact.call(company: @company, policy: policy, after_rules: @change_proposal.after_rule_definitions)
      ActiveRecord::Base.transaction do
        @change_proposal.apply_rule_diff!(@company)
        @change_proposal.update!(status: "approved", decided_by_id: current_person.id, decided_at: Time.current, impact: impact)
      end

      render_success(data: serialize(@change_proposal), message: "Change proposal approved.")
    rescue ChangeProposal::StaleDiff => e
      render_error(message: e.message)
    end

    def set_change_proposal
      @change_proposal = @company.change_proposals.find(params[:id])
    end

    def change_proposal_params
      params.permit(:kind, :title, :proposed_by, diff: [ :op, :person_id, :department_id, :role, :to, :from ])
    end

    def serialize(change_proposal) = change_proposal.as_json(only: FIELDS)
  end
end
