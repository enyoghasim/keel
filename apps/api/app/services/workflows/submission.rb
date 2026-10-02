module Workflows
  # Submits a new request (SPEC.md section 8): saves it, then has
  # Workflows::Runtime start it against the company's active rules, all in
  # one transaction so a request the runtime can't route is never left
  # half-created. Shared by Api::RequestsController and the agent's
  # create_request tool, so both front doors take exactly the same path.
  class Submission
    def self.call(company:, requester:, kind:, payload:)
      ActiveRecord::Base.transaction do
        request = company.requests.create!(requester: requester, kind: kind, payload: payload || {})
        Runtime.new(Org::GraphSnapshot.load(company)).start(request, rules: company.active_rule_definitions(kind))
        request
      end
    end
  end
end
