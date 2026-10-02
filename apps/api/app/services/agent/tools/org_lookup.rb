module Agent
  module Tools
    # Reads the company graph around one person: who they report to, who
    # reports to them, their department head and roles. Pure lookup.
    class OrgLookup < Base
      # Longer than any real reporting line; stops a cycle in bad data.
      MAX_DEPTH = 12

      tool_name "org_lookup"
      description "Look up one person's place in the org chart: their reporting line up to the top, their direct " \
                  "reports, their department head and roles. Find the person_id with search_people first."
      params({
        type: "object", additionalProperties: false, required: [ "person_id" ],
        properties: { person_id: { type: "integer", description: "The person's id, from search_people" } }
      })

      def execute(person_id:)
        record = company.people.includes(:department, :manager).find_by(id: person_id)
        return { "error" => "Person #{person_id} not found in this company." } if record.nil?

        {
          "person" => person_summary(record).merge("roles" => record.roles, "location" => record.location),
          "reporting_line" => reporting_line(record).map { person_summary(_1) },
          "direct_reports" => record.direct_reports.includes(:department).order(:name).map { person_summary(_1) },
          "department_head" => person_summary(record.department&.head)
        }
      end

      private

      def reporting_line(record)
        line = []
        current = record.manager
        while current && line.size < MAX_DEPTH
          line << current
          current = current.manager
        end
        line
      end
    end
  end
end
