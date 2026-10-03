# Encrypts Integration#credentials at rest (Slack webhook URL, Google
# Calendar OAuth tokens). Follows the project's convention for every other
# secret (OPENAI_API_KEY, SECRET_KEY_BASE): a plain env var, not Rails
# credentials — see docker-compose.yml and .env.example. The test
# environment sets its own fixed keys (spec/rails_helper.rb) so specs never
# need real secrets.
Rails.application.config.active_record.encryption.primary_key = ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY", nil)
Rails.application.config.active_record.encryption.deterministic_key = ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY", nil)
Rails.application.config.active_record.encryption.key_derivation_salt = ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT", nil)
