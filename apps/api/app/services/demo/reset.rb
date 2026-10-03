module Demo
  # SPEC.md section 18's "Reset demo": puts a public demo deployment back to a
  # freshly seeded Demo Factorial after visitors have changed it. Destructive,
  # so it only runs where DEMO_RESET=true is set deliberately.
  class Reset
    # Job queue, cache and cable tables belong to the running app, not to the demo's data.
    KEEP = %w[schema_migrations ar_internal_metadata].freeze
    KEEP_PREFIX = "solid_".freeze

    def self.enabled?(env: ENV) = env["DEMO_RESET"] == "true"

    def self.call
      ActiveStorage::Blob.find_each(&:purge)
      truncate_demo_tables
      seed
    end

    def self.truncate_demo_tables
      connection = ActiveRecord::Base.connection
      tables = connection.tables.reject { |t| KEEP.include?(t) || t.start_with?(KEEP_PREFIX) }
      connection.execute("TRUNCATE #{tables.map { connection.quote_table_name(_1) }.join(', ')} RESTART IDENTITY CASCADE")
    end
    private_class_method :truncate_demo_tables

    def self.seed = load(Rails.root.join("db/seeds.rb"))
    private_class_method :seed
  end
end
