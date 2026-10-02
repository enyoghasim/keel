# Seeds the Nubo Logistics demo company (SPEC.md section 16): the company
# graph, the handbook with its rules and workflows, and three months of
# request history run through the real engine. Idempotent — once the
# company exists, running it again does nothing.
#
#   bin/rails db:seed
require_relative "seeds/nubo"
require_relative "seeds/nubo_handbook"
require_relative "seeds/nubo_history"

Seeds::Nubo.call
