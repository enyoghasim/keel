module Seeds
  # The Demo Factorial company graph: a 28-person software company across
  # Barcelona, Madrid and Lisbon. Named people are the ones the demo flows
  # lean on (SPEC.md section 16); everyone else is filled in
  # deterministically so a re-seed always builds the same company.
  module Factorial
    NAME = "Demo Factorial".freeze
    EMAIL_DOMAIN = "factorial.co".freeze
    # The one login surfaced in the README and docker-compose for signing in
    # as the HR admin, instead of the auto-generated name.email@factorial.co.
    DEMO_LOGIN_EMAIL = "demo.hr@factorial.co".freeze

    # [name, title, department, manager name, location, start date, roles]
    KEY_PEOPLE = [
      [ "Marc Vidal", "CEO", "Leadership", nil, "Barcelona", "2016-01-11", [] ],
      [ "Laia Ferrer", "COO", "Leadership", "Marc Vidal", "Barcelona", "2016-09-01", [] ],
      [ "Pol Soler", "CTO", "Leadership", "Marc Vidal", "Barcelona", "2016-11-01", [] ],
      [ "Nuria Costa", "Finance Lead", "Finance", "Marc Vidal", "Barcelona", "2017-03-16", %w[finance_lead] ],
      [ "Beatriz Silva", "Head of People", "People", "Marc Vidal", "Barcelona", "2017-06-02", %w[hr_admin] ],
      [ "Irene Roca", "Head of Product", "Product", "Marc Vidal", "Barcelona", "2017-08-14", [] ],
      [ "Carlos Martinez", "Head of Sales", "Sales", "Laia Ferrer", "Madrid", "2018-01-03", [] ],
      [ "Sofia Oliveira", "Head of Customer Success", "Customer Success", "Laia Ferrer", "Lisbon", "2018-04-19", [] ],
      [ "Diego Fernandez", "Head of Marketing", "Marketing", "Laia Ferrer", "Madrid", "2018-07-23", [] ],
      [ "Tiago Santos", "IT Admin", "IT", "Pol Soler", "Lisbon", "2019-01-06", %w[it_admin] ],
      [ "Catarina Rodrigues", "Account Executive", "Sales", "Carlos Martinez", "Lisbon", "2021-03-01", [] ],
      [ "Alvaro Lopez", "Finance Analyst", "Finance", "Nuria Costa", "Madrid", "2021-07-12", [] ]
    ].freeze

    DEPARTMENT_HEADS = {
      "Leadership" => "Marc Vidal", "Engineering" => "Pol Soler", "Product" => "Irene Roca",
      "Sales" => "Carlos Martinez", "Customer Success" => "Sofia Oliveira", "Marketing" => "Diego Fernandez",
      "Finance" => "Nuria Costa", "People" => "Beatriz Silva", "IT" => "Tiago Santos"
    }.freeze

    # Filler people to add per department; with KEY_PEOPLE this makes 28.
    # Sofia Oliveira's six direct reports come from Customer Success' filler.
    FILLER = {
      "Engineering" => { count: 6, titles: [ "Software Engineer", "Senior Software Engineer", "QA Engineer" ], lead: "Pol Soler" },
      "Product" => { count: 3, titles: [ "Product Designer", "Product Manager" ], lead: "Irene Roca" },
      "Customer Success" => { count: 6, titles: [ "Customer Success Associate", "Support Specialist" ], lead: "Sofia Oliveira" },
      "Marketing" => { count: 1, titles: [ "Marketing Specialist" ], lead: "Diego Fernandez" }
    }.freeze

    FIRST_NAMES = %w[
      Jordi Elena Pau Laia Marc Nuria Oriol Carla Ferran Aina Biel Irene Pol Julia Arnau Alba Gerard Mireia
      Carlos Lucia Javier Diego Paula Sergio Alvaro Cristina Marta Victor Sara Hugo
      Joao Sofia Miguel Beatriz Tiago Catarina Rui Ines Nuno Rita
    ].freeze
    LAST_NAMES = %w[
      Soler Puig Vidal Ferrer Costa Roca Mas Pons Serra Garcia Martinez Lopez Fernandez Ruiz Dominguez
      Silva Pereira Santos Oliveira Rodrigues Carvalho Gomes Nunes
    ].freeze

    def self.call
      return if Company.exists?(name: NAME)

      ActiveRecord::Base.transaction do
        company = Company.create!(name: NAME, assemble_completed_stages: %w[csv_mapping graph_building handbook_chunking policy_extraction workflow_generation])
        build_graph(company)
        FactorialHandbook.call(company)
        FactorialHistory.call(company)
      end
    end

    def self.build_graph(company)
      rng = Random.new(2016)
      digest = BCrypt::Password.create(Person::DEMO_PASSWORD, cost: BCrypt::Engine::MIN_COST)
      departments = DEPARTMENT_HEADS.keys.index_with { Department.create!(company: company, name: _1) }
      people = {}
      used_names = KEY_PEOPLE.map(&:first)

      add = lambda do |name, title, department, manager, location, start_date, roles|
        email = name == "Beatriz Silva" ? DEMO_LOGIN_EMAIL : "#{name.split.join('.').downcase}@#{EMAIL_DOMAIN}"
        people[name] = Person.create!(
          company: company, department: departments.fetch(department), manager: manager && people.fetch(manager),
          name: name, email: email, title: title, location: location,
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
          start = (Date.new(2019, 1, 1) + rng.rand(0..(365 * 6))).iso8601
          add.call(name, config.fetch(:titles)[i % config.fetch(:titles).size], department, manager, %w[Barcelona Madrid Lisbon][i % 3], start, [])
        end
      end

      DEPARTMENT_HEADS.each { |department, head| departments.fetch(department).update!(head: people.fetch(head)) }
    end
    private_class_method :build_graph
  end
end
