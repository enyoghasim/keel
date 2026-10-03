# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
# Fixed dummy ActiveRecord Encryption keys so specs never need real secrets
# (config/initializers/active_record_encryption.rb reads these at boot, so
# they must be set before config/environment loads).
ENV['AR_ENCRYPTION_PRIMARY_KEY'] ||= 'test' * 8
ENV['AR_ENCRYPTION_DETERMINISTIC_KEY'] ||= 'test' * 8
ENV['AR_ENCRYPTION_KEY_DERIVATION_SALT'] ||= 'test' * 8
# Dummy Google Calendar OAuth client so Calendar::TokenRefresher,
# Calendar::EventCreator and GoogleCalendarOauthController specs never need
# a real Google Cloud project — every Google call itself is stubbed. ||=
# isn't enough: docker-compose sets these to "" (via ${VAR:-}) whenever
# .env leaves them blank, and "" is truthy in Ruby.
ENV['GOOGLE_CALENDAR_CLIENT_ID'] = 'test-client-id' if ENV['GOOGLE_CALENDAR_CLIENT_ID'].to_s.empty?
ENV['GOOGLE_CALENDAR_CLIENT_SECRET'] = 'test-client-secret' if ENV['GOOGLE_CALENDAR_CLIENT_SECRET'].to_s.empty?
ENV['GOOGLE_CALENDAR_REDIRECT_URI'] = 'http://localhost:8080/api/companies/1/integrations/google_calendar/callback' if ENV['GOOGLE_CALENDAR_REDIRECT_URI'].to_s.empty?
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
# Uncomment the line below in case you have `--require rails_helper` in the `.rspec` file
# that will avoid rails generators crashing because migrations haven't been run yet
# return unless Rails.env.test?
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Ensures that the test database schema matches the current schema file.
# If there are pending migrations it will invoke `db:test:prepare` to
# recreate the test database by loading the schema.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # Per-IP rate limits count in this store across requests; start each example from zero.
  config.before { ApplicationController.rate_limit_store.clear }

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails uses metadata to mix in different behaviours to your tests,
  # for example enabling you to call `get` and `post` in request specs. e.g.:
  #
  #     RSpec.describe UsersController, type: :request do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/8-0/rspec-rails
  #
  # You can also infer these behaviours automatically by location, e.g.
  # /spec/models would pull in the same behaviour as `type: :model` but this
  # behaviour is considered legacy and will be removed in a future version.
  #
  # To enable this behaviour uncomment the line below.
  # config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
end
