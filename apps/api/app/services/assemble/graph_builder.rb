module Assemble
  # Stage 2 of the Assemble pipeline (SPEC.md section 6): applies a
  # CsvMapper mapping to every row and creates the company graph. Entirely
  # deterministic — no LLM involved. Managers are matched by email, then
  # exact name, then fuzzy name (Levenshtein <= 2); anything that doesn't
  # resolve to exactly one person becomes an ImportIssue rather than a
  # guess.
  class GraphBuilder
    FUZZY_DISTANCE = 2

    def self.call(company:, headers:, rows:, mappings:)
      new(company: company, headers: headers, mappings: mappings).call(rows)
    end

    def initialize(company:, headers:, mappings:)
      @company = company
      @headers = headers
      @mapping_by_column = mappings.index_by(&:source_column)
      @departments_by_name = {}
    end

    def call(rows)
      created = rows.each_with_index.map { |row, i| create_person(row, row_number: i + 2) }
      created.each { |entry| resolve_manager(entry, created) }
      created.map { _1.fetch(:person) }
    end

    private

    def create_person(row, row_number:)
      attrs = extract_attributes(row)
      department = attrs[:department].present? ? find_or_create_department(attrs[:department]) : nil

      person = Person.create!(
        company: @company, department: department,
        name: attrs[:name], email: attrs[:email], title: attrs[:title],
        location: attrs[:location], start_date: attrs[:start_date], roles: RoleInference.for(attrs[:title])
      )

      { person: person, row_number: row_number, manager_raw: attrs[:manager] }
    end

    def extract_attributes(row)
      @headers.each_with_index.each_with_object({}) do |(header, i), attrs|
        mapping = @mapping_by_column[header]
        next if mapping.nil? || mapping.field == "ignore"

        attrs[mapping.field.to_sym] = row[i].presence
      end
    end

    def find_or_create_department(name)
      @departments_by_name[name] ||= Department.find_or_create_by!(company: @company, name: name)
    end

    def resolve_manager(entry, created)
      return if entry[:manager_raw].blank?

      candidates = created.map { _1.fetch(:person) } - [ entry[:person] ]
      manager = match(entry[:manager_raw], candidates)

      if manager
        entry[:person].update!(manager: manager)
      else
        ImportIssue.create!(
          company: @company, row_number: entry[:row_number], field: "manager",
          raw_value: entry[:manager_raw], message: "could not uniquely match manager '#{entry[:manager_raw]}'"
        )
      end
    end

    def match(raw, candidates)
      by_email = candidates.select { _1.email&.casecmp?(raw) }
      return by_email.first if by_email.one?

      by_name = candidates.select { _1.name.casecmp?(raw) }
      return by_name.first if by_name.one?

      by_fuzzy = candidates.select { Levenshtein.distance(_1.name.downcase, raw.downcase) <= FUZZY_DISTANCE }
      return by_fuzzy.first if by_fuzzy.one?

      nil
    end
  end
end
