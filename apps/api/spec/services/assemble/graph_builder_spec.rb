require "rails_helper"

RSpec.describe Assemble::GraphBuilder do
  # Mirrors SPEC.md section 6, stage 2: applying a CsvMapper mapping to CSV
  # rows is plain Ruby, no LLM involved — one example per matching tier.
  def mapping(source_column:, field:) = Assemble::CsvMapper::Mapping.new(source_column, field, 1.0)

  let(:headers) { [ "Full Name", "E-mail", "Dept", "Line Mgr" ] }
  let(:mappings) do
    [
      mapping(source_column: "Full Name", field: "name"),
      mapping(source_column: "E-mail", field: "email"),
      mapping(source_column: "Dept", field: "department"),
      mapping(source_column: "Line Mgr", field: "manager")
    ]
  end

  it "creates a department and a person for each row" do
    company = create(:company)
    rows = [ [ "Ada Nwosu", "ada@nubo.example", "Engineering", "" ] ]

    people = described_class.call(company: company, headers: headers, rows: rows, mappings: mappings)

    expect(people.size).to eq(1)
    expect(people.first).to have_attributes(name: "Ada Nwosu", email: "ada@nubo.example")
    expect(people.first.department.name).to eq("Engineering")
    expect(company.import_issues).to be_empty
  end

  it "gives a person the roles their job title implies, so role references have a holder" do
    company = create(:company)
    titled = Assemble::CsvMapper::Mapping.new("Job Title", "title", 1.0)
    rows = [ [ "Amaka Obi", "amaka@nubo.example", "Finance", "", "Finance Lead" ], [ "Ada Nwosu", "ada@nubo.example", "Finance", "", "Accountant" ] ]

    people = described_class.call(company: company, headers: headers + [ "Job Title" ], rows: rows, mappings: mappings + [ titled ])

    expect(people.map(&:roles)).to eq([ %w[finance_lead], [] ])
  end

  it "reuses an existing department for people in the same department" do
    company = create(:company)
    rows = [
      [ "Ada Nwosu", "ada@nubo.example", "Engineering", "" ],
      [ "Ngozi Eze", "ngozi@nubo.example", "Engineering", "" ]
    ]

    people = described_class.call(company: company, headers: headers, rows: rows, mappings: mappings)

    expect(people.map { _1.department.id }.uniq.size).to eq(1)
  end

  it "ignores columns mapped to 'ignore'" do
    company = create(:company)
    headers_with_badge = headers + [ "Badge #" ]
    mappings_with_badge = mappings + [ mapping(source_column: "Badge #", field: "ignore") ]
    rows = [ [ "Ada Nwosu", "ada@nubo.example", "Engineering", "", "117" ] ]

    people = described_class.call(company: company, headers: headers_with_badge, rows: rows, mappings: mappings_with_badge)

    expect(people.first).to have_attributes(name: "Ada Nwosu")
  end

  it "matches a manager by email" do
    company = create(:company)
    rows = [
      [ "Tunde Bakare", "tunde@nubo.example", "Engineering", "" ],
      [ "Ngozi Eze", "ngozi@nubo.example", "Engineering", "tunde@nubo.example" ]
    ]

    people = described_class.call(company: company, headers: headers, rows: rows, mappings: mappings)
    ngozi = people.find { _1.name == "Ngozi Eze" }
    tunde = people.find { _1.name == "Tunde Bakare" }

    expect(ngozi.manager).to eq(tunde)
    expect(company.import_issues).to be_empty
  end

  it "matches a manager by exact name when no email is given" do
    company = create(:company)
    rows = [
      [ "Tunde Bakare", "tunde@nubo.example", "Engineering", "" ],
      [ "Ngozi Eze", "ngozi@nubo.example", "Engineering", "Tunde Bakare" ]
    ]

    people = described_class.call(company: company, headers: headers, rows: rows, mappings: mappings)
    ngozi = people.find { _1.name == "Ngozi Eze" }
    tunde = people.find { _1.name == "Tunde Bakare" }

    expect(ngozi.manager).to eq(tunde)
  end

  it "matches a manager despite a typo, within Levenshtein distance 2" do
    company = create(:company)
    rows = [
      [ "Tunde Bakare", "tunde@nubo.example", "Engineering", "" ],
      [ "Ngozi Eze", "ngozi@nubo.example", "Engineering", "Tunde Bakre" ]
    ]

    people = described_class.call(company: company, headers: headers, rows: rows, mappings: mappings)
    ngozi = people.find { _1.name == "Ngozi Eze" }
    tunde = people.find { _1.name == "Tunde Bakare" }

    expect(ngozi.manager).to eq(tunde)
  end

  it "records an import issue when a manager reference matches nobody" do
    company = create(:company)
    rows = [ [ "Ngozi Eze", "ngozi@nubo.example", "Engineering", "Nobody Here" ] ]

    people = described_class.call(company: company, headers: headers, rows: rows, mappings: mappings)

    expect(people.first.manager).to be_nil
    issue = company.import_issues.sole
    expect(issue).to have_attributes(row_number: 2, field: "manager", raw_value: "Nobody Here")
  end

  it "records an import issue when a manager reference matches more than one person" do
    company = create(:company)
    rows = [
      [ "Tunde Bakare", "tunde.o@nubo.example", "Engineering", "" ],
      [ "Tunde Bakare", "tunde.b@nubo.example", "Engineering", "" ],
      [ "Ngozi Eze", "ngozi@nubo.example", "Engineering", "Tunde Bakare" ]
    ]

    people = described_class.call(company: company, headers: headers, rows: rows, mappings: mappings)

    ngozi = people.find { _1.name == "Ngozi Eze" }
    expect(ngozi.manager).to be_nil
    expect(company.import_issues.sole).to have_attributes(row_number: 4, field: "manager", raw_value: "Tunde Bakare")
  end
end
