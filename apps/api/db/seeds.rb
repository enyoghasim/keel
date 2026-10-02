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

# Seeding itself never needs a model key; with one, the handbook chunks get
# embedded too so the agent's search_handbook can use vector search. Runs on
# every `db:seed`, so adding a key later and re-seeding fills them in
# (or `bin/rails handbook:embed`).
begin
  embedded = Assemble::ChunkEmbedder.embed_missing
  puts "Embedded #{embedded} handbook chunks." if embedded.positive?
rescue StandardError => e
  warn "Skipped embedding handbook chunks: #{e.class}: #{e.message}"
end
