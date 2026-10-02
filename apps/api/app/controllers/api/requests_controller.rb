module Api
  # Creating a request runs the full decide-then-route lifecycle from
  # SPEC.md section 8: Rules::Engine decides, and Workflows::Runtime
  # either short-circuits (auto_approve/reject/blocked) or starts the
  # matching active workflow and resolves its first step.
  class RequestsController < ApplicationController
    include CompanyScoped

    FIELDS = %i[id company_id requester_id kind payload decision matched_rule_ids policy_version status created_at].freeze

    before_action :set_request, only: [ :show ]
    before_action :require_current_person!, only: [ :create ]

    def index
      scope = @company.requests
      scope = scope.where(requester_id: params[:requester_id]) if params[:requester_id].present?
      scope = scope.where(status: params[:status]) if params[:status].present?
      render_success(data: scope.map { serialize(_1) })
    end

    def show
      render_success(data: serialize(@request_record))
    end

    def create
      requester = @company.people.find_by(id: request_params[:requester_id])
      return render_error(message: "requester not found in this company") if requester.nil?
      unless current_person.id == requester.id || current_person.hr_admin?
        return render_error(message: "you can only create requests for yourself", status: :forbidden)
      end

      request_record = nil

      ActiveRecord::Base.transaction do
        request_record = @company.requests.create!(
          requester: requester, kind: request_params[:kind], payload: request_params[:payload] || {}
        )
        snapshot = Org::GraphSnapshot.load(@company)
        Workflows::Runtime.new(snapshot).start(request_record, rules: active_rules_for(request_record.kind))
      end

      render_success(data: serialize(request_record.reload), message: "Request created.", status: :created)
    rescue ActiveRecord::RecordInvalid => e
      render_error(message: e.message, errors: e.record.errors.full_messages)
    end

    private

    def set_request
      @request_record = @company.requests.find(params[:id])
    end

    def active_rules_for(kind)
      @company.policies.where(status: "active", category: kind).flat_map do |policy|
        policy.rules.where(status: "active").map(&:to_rule_definition)
      end
    end

    def request_params
      params.permit(:requester_id, :kind, payload: {})
    end

    def serialize(request_record)
      request_record.as_json(only: FIELDS).merge(
        "workflow_run" => request_record.workflow_run && serialize_workflow_run(request_record.workflow_run)
      )
    end

    def serialize_workflow_run(workflow_run)
      workflow_run.as_json(only: %i[id status current_step]).merge(
        "step_runs" => workflow_run.step_runs.map do
          _1.as_json(only: %i[id step_key reference resolved_person_id status acted_at overridden override_reason])
        end
      )
    end
  end
end
