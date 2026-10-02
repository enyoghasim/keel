module Api
  class RulesController < ApplicationController
    include CompanyScoped

    FIELDS = %i[id key conditions actions priority source_quote ambiguities status policy_id].freeze

    before_action :set_policy

    def index
      render_success(data: @policy.rules.map { self.class.serialize(_1) })
    end

    def show
      render_success(data: self.class.serialize(@policy.rules.find(params[:id])))
    end

    def self.serialize(rule) = rule.as_json(only: FIELDS)

    private

    def set_policy
      @policy = @company.policies.find(params[:policy_id])
    end
  end
end
