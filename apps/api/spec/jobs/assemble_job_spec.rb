require "rails_helper"

RSpec.describe AssembleJob, type: :job do
  include ActionCable::TestHelper

  # The five stages are already thoroughly tested on their own (CsvMapper,
  # GraphBuilder, HandbookChunker, ChunkEmbedder, PolicyExtractor,
  # WorkflowGenerator specs) — this job is responsible for sequencing them,
  # broadcasting progress, and skipping whatever's already done on a retry,
  # so that's what these examples check. The stages themselves are stubbed.
  let(:company) { create(:company) }
  let(:mapping) { [ Assemble::CsvMapper::Mapping.new("Name", "name", 1.0) ] }
  let(:person) { create(:person, company: company) }
  let(:document) { create(:source_document, company: company) }
  let(:chunk) { create(:chunk, source_document: document) }
  let(:policy) { create(:policy, company: company, category: "equipment") }
  let(:rule) { create(:rule, policy: policy, source_chunk: chunk) }
  let(:workflow) { create(:workflow, company: company) }

  before do
    company.roster_csv.attach(io: StringIO.new("Name\nAda Nwosu"), filename: "roster.csv", content_type: "text/csv")
    document # ensure it exists before the job runs

    allow(Assemble::CsvMapper).to receive(:call).and_return(mapping)
    allow(Assemble::GraphBuilder).to receive(:call).and_return([ person ])
    allow(Assemble::HandbookChunker).to receive(:call).and_return([ chunk ])
    allow(Assemble::ChunkEmbedder).to receive(:call).and_return([ chunk ])
    # Only "equipment" has relevant chunks, so extraction/generation run exactly
    # once each — the other four categories are skipped, same as a company
    # whose handbook simply doesn't cover them.
    allow(Assemble::PolicyExtractor).to receive(:relevant_chunks_for) do |company:, category:|
      category == "equipment" ? [ chunk ] : []
    end
    allow(Assemble::PolicyExtractor).to receive(:call)
      .and_return(Assemble::PolicyExtractor::Result.new(policy: policy, rules: [ rule ], rejected: []))
    allow(Assemble::WorkflowGenerator).to receive(:call).and_return(workflow)
  end

  it "runs all five stages and marks them completed, in order, on the company" do
    described_class.perform_now(company.id)

    expect(Assemble::CsvMapper).to have_received(:call)
    expect(Assemble::GraphBuilder).to have_received(:call)
    expect(Assemble::HandbookChunker).to have_received(:call)
    expect(Assemble::PolicyExtractor).to have_received(:call).once
    expect(Assemble::WorkflowGenerator).to have_received(:call).once

    expect(company.reload.assemble_completed_stages).to eq(
      %w[csv_mapping graph_building handbook_chunking policy_extraction workflow_generation]
    )
  end

  it "broadcasts a person_added event for every person the graph builder returns" do
    expect { described_class.perform_now(company.id) }
      .to have_broadcasted_to(company).from_channel(AssembleChannel).with(hash_including("stage" => "graph", "event" => "person_added"))
  end

  it "broadcasts a workflow_generated event for each generated workflow" do
    expect { described_class.perform_now(company.id) }
      .to have_broadcasted_to(company).from_channel(AssembleChannel).with(hash_including("stage" => "workflows", "event" => "workflow_generated"))
  end

  it "broadcasts an import_issue event for each row the graph builder could not resolve" do
    ImportIssue.create!(company: company, row_number: 78, field: "manager", raw_value: "Chidi Unknownson", message: "could not uniquely match manager 'Chidi Unknownson'")

    expect { described_class.perform_now(company.id) }
      .to have_broadcasted_to(company).from_channel(AssembleChannel).with(
        hash_including("stage" => "graph", "event" => "import_issue",
                       "data" => hash_including("row_number" => 78, "field" => "manager", "raw_value" => "Chidi Unknownson"))
      )
  end

  it "broadcasts a rule_rejected event for a rule whose source quote was not in the handbook" do
    allow(Assemble::PolicyExtractor).to receive(:call).and_return(
      Assemble::PolicyExtractor::Result.new(
        policy: policy, rules: [ rule ],
        rejected: [ { "key" => "expense_cfo", "source_quote" => "The CFO must countersign." } ]
      )
    )

    expect { described_class.perform_now(company.id) }
      .to have_broadcasted_to(company).from_channel(AssembleChannel).with(
        hash_including("stage" => "policies", "event" => "rule_rejected",
                       "data" => hash_including("key" => "expense_cfo", "source_quote" => "The CFO must countersign."))
      )
  end

  it "says in each rule_extracted event whether the rule still has a question for a person" do
    rule.update!(ambiguities: [ { "phrase" => "up to", "question" => "Including travel?", "options" => [ "Yes", "No" ] } ])

    expect { described_class.perform_now(company.id) }
      .to have_broadcasted_to(company).from_channel(AssembleChannel).with(
        hash_including("event" => "rule_extracted", "data" => hash_including("needs_input" => true))
      )
  end

  it "tells the page why it stopped, in words a person can act on, when a stage fails" do
    allow(Assemble::CsvMapper).to receive(:call).and_raise(RubyLLM::ConfigurationError, "Missing configuration for OpenAI: openai_api_key")

    expect { described_class.perform_now(company.id) }
      .to have_broadcasted_to(company).from_channel(AssembleChannel)
      .with(hash_including("event" => "failed", "data" => { "message" => Llm::Failure::NO_MODEL }))
      .and raise_error(RubyLLM::ConfigurationError)

    expect(company.reload.assemble_events.last["event"]).to eq("failed")
  end

  it "skips stages already marked complete, for a retried job" do
    company.update!(assemble_completed_stages: %w[csv_mapping graph_building])

    described_class.perform_now(company.id)

    expect(Assemble::CsvMapper).not_to have_received(:call)
    expect(Assemble::GraphBuilder).not_to have_received(:call)
    expect(Assemble::HandbookChunker).to have_received(:call)
  end
end

RSpec.describe AssembleJob, "event log", type: :job do
  let(:company) { create(:company) }
  let(:person) { create(:person, company: company) }

  before do
    company.roster_csv.attach(io: StringIO.new("Name\nAda Nwosu"), filename: "roster.csv", content_type: "text/csv")
    allow(Assemble::CsvMapper).to receive(:call).and_return([ Assemble::CsvMapper::Mapping.new("Name", "name", 1.0) ])
    allow(Assemble::GraphBuilder).to receive(:call).and_return([ person ])
    allow(Assemble::PolicyExtractor).to receive(:relevant_chunks_for).and_return([]) # no handbook, so no model calls
  end

  it "keeps every event it broadcasts on the company, numbered, so a browser that subscribed late can catch up" do
    described_class.perform_now(company.id)

    events = company.reload.assemble_events
    expect(events.map { _1["seq"] }).to eq((0...events.size).to_a)
    expect(events.map { _1["event"] }).to start_with("mapping_complete", "person_added")
  end

  it "broadcasts the same numbered event it stores" do
    expect { described_class.perform_now(company.id) }
      .to have_broadcasted_to(company).from_channel(AssembleChannel).with(hash_including("event" => "mapping_complete", "seq" => 0))
  end
end
