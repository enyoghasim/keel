require "csv"

# Sequences the five Assemble pipeline stages (SPEC.md section 6) for one
# company and broadcasts progress on AssembleChannel as it goes. Each
# stage is recorded as done on the company once it finishes, so retrying
# a failed job resumes after the last completed stage instead of redoing
# everything (section 6's failure handling).
class AssembleJob < ApplicationJob
  ALL_CATEGORIES = %w[leave expense remote equipment onboarding].freeze
  STAGES = %w[csv_mapping graph_building handbook_chunking policy_extraction workflow_generation].freeze
  REQUEST_KIND_CATEGORIES = %w[leave expense equipment].freeze

  def perform(company_id)
    @company = Company.find(company_id)
    @policies_by_category = {}

    run_stage("csv_mapping") { map_csv }
    run_stage("graph_building") { build_graph }
    run_stage("handbook_chunking") { chunk_handbook }
    run_stage("policy_extraction") { extract_policies }
    run_stage("workflow_generation") { generate_workflows }
  end

  private

  def run_stage(name)
    return if @company.assemble_completed_stages.include?(name)

    yield
    @company.update!(assemble_completed_stages: @company.assemble_completed_stages + [ name ])
  end

  def map_csv
    table = CSV.parse(@company.roster_csv.download)
    @headers = table.first
    @rows = table.drop(1)

    @mapping = Assemble::CsvMapper.call(headers: @headers, sample_rows: @rows.first(10))
    broadcast(stage: "csv", event: "mapping_complete", data: { mappings: @mapping.map(&:to_h) }, progress: 0.1)
  end

  def build_graph
    people = Assemble::GraphBuilder.call(company: @company, headers: @headers, rows: @rows, mappings: @mapping)

    people.each_with_index do |person, i|
      broadcast(
        stage: "graph", event: "person_added",
        data: { id: person.id, name: person.name, manager_id: person.manager_id, department: person.department&.name },
        progress: 0.1 + 0.3 * (i + 1) / people.size
      )
    end
  end

  def chunk_handbook
    document = @company.source_documents.first
    return if document.nil?

    chunks = Assemble::HandbookChunker.call(source_document: document)
    Assemble::ChunkEmbedder.call(chunks: chunks)
    broadcast(stage: "handbook", event: "chunks_embedded", data: { count: chunks.size }, progress: 0.5)
  end

  def extract_policies
    ALL_CATEGORIES.each_with_index do |category, i|
      chunks = Assemble::PolicyExtractor.relevant_chunks_for(company: @company, category: category)
      next if chunks.empty?

      result = Assemble::PolicyExtractor.call(company: @company, category: category, chunks: chunks)
      @policies_by_category[category] = result.policy

      result.rules.each do |rule|
        broadcast(
          stage: "policies", event: "rule_extracted",
          data: { id: rule.id, key: rule.key, policy_id: rule.policy_id, category: category },
          progress: 0.5 + 0.3 * (i + 1) / ALL_CATEGORIES.size
        )
      end
    end
  end

  def generate_workflows
    REQUEST_KIND_CATEGORIES.each_with_index do |category, i|
      policy = @policies_by_category[category]
      next if policy.nil? || policy.rules.none?

      workflow = Assemble::WorkflowGenerator.call(company: @company, request_kind: category, rules: policy.rules)
      broadcast(
        stage: "workflows", event: "workflow_generated",
        data: { id: workflow.id, request_kind: category },
        progress: 0.8 + 0.2 * (i + 1) / REQUEST_KIND_CATEGORIES.size
      )
    end
  end

  # Every event is numbered and kept on the company as well as broadcast: a
  # browser that subscribes after the job started (or reloads mid-run) reads
  # the log from the API and merges by seq instead of staring at an empty page.
  def broadcast(stage:, event:, data:, progress:)
    @seq ||= @company.assemble_events.size
    payload = { "seq" => @seq, "stage" => stage, "event" => event, "data" => data.as_json, "progress" => progress }
    @seq += 1

    Company.where(id: @company.id).update_all([ "assemble_events = assemble_events || ?::jsonb", [ payload ].to_json ])
    AssembleChannel.broadcast_to(@company, payload)
  end
end
