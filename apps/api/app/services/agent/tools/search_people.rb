module Agent
  module Tools
    # Looks people up in the company graph by name, title or department.
    class SearchPeople < Base
      LIMIT = 10

      tool_name "search_people"
      description "Find people in the company by name, job title or department. Returns up to 10 matches with " \
                  "their id, title, department and manager. Use it to identify a person before talking about them."
      params({
        type: "object", additionalProperties: false, required: [ "query" ],
        properties: { query: { type: "string", description: "Part of a name, title or department name" } }
      })

      def execute(query:)
        pattern = "%#{Person.sanitize_sql_like(query.to_s.strip)}%"
        matches = company.people.left_joins(:department).includes(:department, :manager)
                         .where("people.name ILIKE :p OR people.title ILIKE :p OR departments.name ILIKE :p", p: pattern)
                         .order(:name).limit(LIMIT)

        { "people" => matches.map { person_summary(_1).merge("manager" => _1.manager&.name, "roles" => _1.roles) } }
      end
    end
  end
end
