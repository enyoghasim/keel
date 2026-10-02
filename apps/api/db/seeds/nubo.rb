module Seeds
  # The Nubo Logistics company graph: 78 people in nine departments across
  # Lagos, Abuja and Barcelona. Named people are the ones the demo flows
  # lean on (SPEC.md section 16); everyone else is filled in
  # deterministically so a re-seed always builds the same company.
  module Nubo
    NAME = "Nubo Logistics".freeze

    # [name, title, department, manager name, location, start date, roles]
    KEY_PEOPLE = [
      [ "Folake Adeniyi", "CEO", "Leadership", nil, "Lagos", "2014-03-01", [] ],
      [ "Kelechi Obi", "COO", "Leadership", "Folake Adeniyi", "Lagos", "2015-02-01", [] ],
      [ "Danjuma Bello", "CTO", "Leadership", "Folake Adeniyi", "Abuja", "2016-06-01", [] ],
      [ "Amaka Obi", "Finance Lead", "Finance", "Folake Adeniyi", "Lagos", "2017-01-16", %w[finance_lead] ],
      [ "Ifeoma Adeyemi", "Head of People", "People", "Folake Adeniyi", "Lagos", "2018-04-02", %w[hr_admin] ],
      [ "Tunde Bakare", "Head of Sales", "Sales", "Kelechi Obi", "Lagos", "2018-09-03", [] ],
      [ "Ada Nwosu", "Operations Lead", "Operations", "Kelechi Obi", "Lagos", "2019-01-14", [] ],
      [ "Bisi Lawal", "Operations Lead", "Operations", "Kelechi Obi", "Abuja", "2019-05-06", [] ],
      [ "Musa Garba", "Head of Warehouse", "Warehouse", "Kelechi Obi", "Abuja", "2018-02-05", [] ],
      [ "Zainab Sani", "Head of Support", "Customer Support", "Kelechi Obi", "Lagos", "2019-08-19", [] ],
      [ "Emeka Nnadi", "IT Admin", "IT", "Danjuma Bello", "Lagos", "2020-01-06", %w[it_admin] ],
      [ "Ngozi Eze", "Account Executive", "Sales", "Tunde Bakare", "Lagos", "2021-03-01", [] ],
      [ "Chioma Okafor", "Finance Analyst", "Finance", "Amaka Obi", "Lagos", "2021-07-12", [] ]
    ].freeze

    DEPARTMENT_HEADS = {
      "Leadership" => "Folake Adeniyi", "Operations" => "Ada Nwosu", "Sales" => "Tunde Bakare",
      "Engineering" => "Danjuma Bello", "Finance" => "Amaka Obi", "People" => "Ifeoma Adeyemi",
      "IT" => "Emeka Nnadi", "Customer Support" => "Zainab Sani", "Warehouse" => "Musa Garba"
    }.freeze

    # Filler people to add per department; with KEY_PEOPLE this makes 78.
    # Ada Nwosu's six direct reports come from Operations' filler; the
    # rest of Operations reports to Bisi Lawal.
    FILLER = {
      "Operations" => { count: 10, titles: [ "Operations Coordinator", "Logistics Planner", "Dispatcher" ], lead: "Ada Nwosu", lead_reports: 6, other_lead: "Bisi Lawal" },
      "Sales" => { count: 9, titles: [ "Account Executive", "Sales Development Rep" ], lead: "Tunde Bakare" },
      "Engineering" => { count: 14, titles: [ "Software Engineer", "Senior Software Engineer", "QA Engineer" ], lead: "Danjuma Bello" },
      "Finance" => { count: 4, titles: [ "Accountant", "Payroll Specialist" ], lead: "Amaka Obi" },
      "People" => { count: 3, titles: [ "People Partner", "Recruiter" ], lead: "Ifeoma Adeyemi" },
      "IT" => { count: 3, titles: [ "IT Support Specialist", "Systems Engineer" ], lead: "Emeka Nnadi" },
      "Customer Support" => { count: 11, titles: [ "Support Agent", "Support Specialist" ], lead: "Zainab Sani" },
      "Warehouse" => { count: 11, titles: [ "Warehouse Associate", "Forklift Operator", "Inventory Clerk" ], lead: "Musa Garba" }
    }.freeze

    FIRST_NAMES = %w[
      Chinedu Funmi Ibrahim Hauwa Obinna Yetunde Segun Halima Uche Adaeze Kunle Maryam Tobi Nneka Femi Aisha
      Ikenna Titilayo Dayo Zara Kelvin Ruth Sola Hadiza Jide Ebele Lola Yusuf Amara Bayo Tope Ngozi Carlos Marta
      Jordi Elena Pau Laia Marc Nuria Oriol Carla Ferran Aina Biel Irene Pol Julia Arnau Alba Gerard Mireia
    ].freeze
    LAST_NAMES = %w[
      Okonkwo Balogun Abubakar Nwachukwu Ogunleye Danladi Chukwu Akinola Yakubu Onyeama Fashola Mohammed Eze
      Olaniyan Usman Idowu Obasi Salami Adebayo Nweke Garcia Soler Puig Vidal Ferrer Costa Roca Mas Pons Serra
    ].freeze

    def self.call
      return if Company.exists?(name: NAME)

      ActiveRecord::Base.transaction do
        company = Company.create!(name: NAME, assemble_completed_stages: %w[csv_mapping graph_building handbook_chunking policy_extraction workflow_generation])
        build_graph(company)
        NuboHandbook.call(company)
        NuboHistory.call(company)
      end
    end

    def self.build_graph(company)
      rng = Random.new(2014)
      digest = BCrypt::Password.create(Person::DEMO_PASSWORD, cost: BCrypt::Engine::MIN_COST)
      departments = DEPARTMENT_HEADS.keys.index_with { Department.create!(company: company, name: _1) }
      people = {}
      used_names = KEY_PEOPLE.map(&:first)

      add = lambda do |name, title, department, manager, location, start_date, roles|
        people[name] = Person.create!(
          company: company, department: departments.fetch(department), manager: manager && people.fetch(manager),
          name: name, email: "#{name.split.join('.').downcase}@nubo.test", title: title, location: location,
          start_date: Date.parse(start_date), roles: roles, password_digest: digest
        )
      end

      KEY_PEOPLE.each { |attrs| add.call(*attrs) }

      FILLER.each do |department, config|
        config.fetch(:count).times do |i|
          name = loop do
            candidate = "#{FIRST_NAMES.sample(random: rng)} #{LAST_NAMES.sample(random: rng)}"
            break candidate unless used_names.include?(candidate)
          end
          used_names << name

          manager = config.fetch(:lead)
          manager = config.fetch(:other_lead) if config[:lead_reports] && i >= config.fetch(:lead_reports)
          start = (Date.new(2019, 1, 1) + rng.rand(0..(365 * 6))).iso8601
          add.call(name, config.fetch(:titles)[i % config.fetch(:titles).size], department, manager, %w[Lagos Abuja Barcelona][i % 3], start, [])
        end
      end

      DEPARTMENT_HEADS.each { |department, head| departments.fetch(department).update!(head: people.fetch(head)) }
    end
    private_class_method :build_graph
  end
end
