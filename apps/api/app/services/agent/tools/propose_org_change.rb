module Agent
  module Tools
    # The "Change" kind of agent request (SPEC.md section 9): turns the
    # model's structured operations into a ChangeProposal with a computed
    # impact report (Impact::OrgImpact) and links it to this run's trace.
    # Nothing about the org changes here — AGENTS.md rule 2: a human
    # approves the proposal on /proposals and only then is it applied.
    # Idempotent within a run, like create_request.
    class ProposeOrgChange < Base
      OPERATIONS = %w[move_person change_manager set_department_head assign_role].freeze
      REQUIRED_FIELDS = {
        "move_person" => %w[person_id department_id],
        "change_manager" => %w[person_id to],
        "set_department_head" => %w[department_id to],
        "assign_role" => %w[person_id role]
      }.freeze

      tool_name "propose_org_change"
      description "Propose a change to the org chart — move a person to a department, change someone's manager, " \
                  "set a department head or assign a role. This does NOT change anything: it records a proposal " \
                  "with a computed impact report that an HR admin must approve. Use search_people and org_lookup " \
                  "first to find the right ids. Only hr_admin people can use it."
      params({
        type: "object", additionalProperties: false, required: %w[title operations],
        properties: {
          title: { type: "string", description: "Short title, e.g. 'Move Sales under Ada Nwosu'" },
          operations: {
            type: "array", minItems: 1,
            items: {
              type: "object", additionalProperties: false, required: [ "op" ],
              properties: {
                op: { type: "string", enum: OPERATIONS },
                person_id: { type: "integer", description: "The person being moved, re-managed or given a role" },
                department_id: { type: "integer", description: "The department to move into, or whose head changes" },
                to: { type: %w[integer null], description: "New manager or department head (a person id); null for nobody" },
                role: { type: "string", description: "Role tag to assign, e.g. finance_lead" }
              }
            }
          }
        }
      })

      def initialize(context)
        super
        @created = {}
      end

      def execute(title:, operations:)
        require_hr_admin!("propose org changes")

        diff = operations.map { build_operation(_1.to_h.stringify_keys) }
        @created[[ title, diff ]] ||= create_proposal(title, diff)

        summarize(@created[[ title, diff ]])
      end

      private

      def build_operation(op)
        missing = REQUIRED_FIELDS.fetch(op["op"]).reject { op.key?(_1) }
        raise ArgumentError, "#{op['op']} needs #{missing.join(', ')}" if missing.any?

        case op["op"]
        when "move_person"
          { "op" => "move_person", "person_id" => find_person!(op["person_id"]).id, "department_id" => find_department!(op["department_id"]).id }
        when "change_manager"
          subject = find_person!(op["person_id"])
          { "op" => "change_manager", "person_id" => subject.id, "from" => subject.manager_id, "to" => op["to"] && find_person!(op["to"]).id }
        when "set_department_head"
          department = find_department!(op["department_id"])
          { "op" => "set_department_head", "department_id" => department.id, "from" => department.head_id, "to" => op["to"] && find_person!(op["to"]).id }
        when "assign_role"
          { "op" => "assign_role", "person_id" => find_person!(op["person_id"]).id, "role" => op["role"] }
        end
      end

      def find_person!(id)
        company.people.find_by(id: id) || raise(ArgumentError, "Person #{id} not found in this company")
      end

      def find_department!(id)
        company.departments.find_by(id: id) || raise(ArgumentError, "Department #{id} not found in this company")
      end

      def create_proposal(title, diff)
        company.change_proposals.create!(
          kind: "org", title: title, diff: diff, proposed_by: "agent", agent_run: context.agent_run,
          impact: Impact::OrgImpact.call(company: company, diff: diff)
        )
      end

      # The stored impact has one entry per person per scenario; the model
      # (and the person reading its answer) wants a head count.
      def people_affected(proposal, category) = proposal.impact[category].map { _1["person_id"] }.uniq.size

      def summarize(proposal)
        {
          "proposal_id" => proposal.id, "status" => proposal.status, "link" => "/proposals",
          "rerouted" => people_affected(proposal, "rerouted"), "broken" => people_affected(proposal, "broken"),
          "self_approval" => people_affected(proposal, "self_approval"),
          "note" => "Nothing has changed yet. An HR admin has to review and approve this proposal on the Proposals page."
        }
      end
    end
  end
end
