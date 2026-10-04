module Agent
  module Tools
    # The "Change" kind of agent request (SPEC.md section 9): turns the
    # model's structured operations into a ChangeProposal with a computed
    # impact report (Impact::OrgImpact) and links it to this run's trace.
    # AGENTS.md rule 2: a human approves the proposal, and only then is it
    # applied — see auto_approve! below for when that human is the same
    # hr_admin asking and nothing broke, which decides it immediately
    # instead of waiting for a separate trip to /proposals. Anything with
    # broken chains still lands there pending, untouched.
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
                  "set a department head or assign a role. Records a proposal with a computed impact report; if " \
                  "nothing breaks, it's approved immediately since only an hr_admin could approve it anyway and " \
                  "that's who's asking. If it breaks approval chains, it's left pending for manual review with " \
                  "\"approve anyway\" on the Proposals page instead. Use search_people and org_lookup first to " \
                  "find the right ids — a department_id comes from org_lookup's or search_people's " \
                  "department_id field for someone already in it, never guessed from the department's name. " \
                  "Only hr_admin people can use it."
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

        # Keyed on the raw call, not the computed diff: an auto-approved
        # proposal (see create_proposal) applies immediately, so a repeat of
        # the same call later in the run would otherwise compute a different
        # "from" and miss the cache.
        key = [ title, operations ]
        @created[key] ||= create_proposal(title, operations.map { build_operation(_1.to_h.stringify_keys) })

        summarize(@created[key])
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
        impact = Impact::OrgImpact.call(company: company, diff: diff)
        proposal = company.change_proposals.create!(
          kind: "org", title: title, diff: diff, proposed_by: "agent", agent_run: context.agent_run, impact: impact
        )
        auto_approve!(proposal) if impact["broken"].empty?
        proposal
      end

      # require_hr_admin! above already guarantees the person asking is an
      # hr_admin — the same, and only, gate ChangeProposalsController#approve
      # checks (SPEC.md section 10). So when nothing broke, this person could
      # walk straight to /proposals and approve their own request anyway;
      # skip that extra click and decide it now instead. Still a human
      # decision (rule 2) — just this person's, made at request time — and
      # still recorded with decided_by/decided_at like any other approval.
      # A proposal with broken chains still needs the manual "approve
      # anyway" + reason flow, same as it would for any other reviewer.
      def auto_approve!(proposal)
        ActiveRecord::Base.transaction do
          proposal.apply_org_diff!(company)
          proposal.update!(status: "approved", decided_by_id: person.id, decided_at: Time.current)
        end
      end

      # The stored impact has one entry per person per scenario; the model
      # (and the person reading its answer) wants a head count.
      def people_affected(proposal, category) = proposal.impact[category].map { _1["person_id"] }.uniq.size

      def summarize(proposal)
        note = if proposal.status == "approved"
          "Approved automatically — you're the hr_admin who'd have had to approve it anyway."
        else
          "Nothing has changed yet. An HR admin has to review and approve this proposal on the Proposals page."
        end

        {
          "proposal_id" => proposal.id, "status" => proposal.status, "link" => "/proposals",
          "rerouted" => people_affected(proposal, "rerouted"), "broken" => people_affected(proposal, "broken"),
          "self_approval" => people_affected(proposal, "self_approval"), "note" => note
        }
      end
    end
  end
end
