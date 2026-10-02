module Assemble
  # The embedding half of stage 3 (SPEC.md section 6): one batched
  # RubyLLM.embed call for every chunk's text, saved into the pgvector
  # column. Kept separate from HandbookChunker so the chunking algorithm
  # stays testable without mocking the LLM.
  class ChunkEmbedder
    BATCH_SIZE = 64

    # Whether an embedding model is reachable: an OpenAI key (the default
    # embedding model) or a custom OpenAI-compatible API base.
    def self.available?
      RubyLLM.config.openai_api_key.present? || RubyLLM.config.openai_api_base.present?
    end

    # Embeds every chunk that has no embedding yet (seeded handbooks start
    # that way — seeding must not need a model key). Returns how many it
    # embedded; zero, without calling the model, when none is configured.
    def self.embed_missing(company: nil, batch_size: BATCH_SIZE)
      return 0 unless available?

      scope = Chunk.where(embedding: nil)
      scope = scope.joins(:source_document).where(source_documents: { company_id: company.id }) if company
      scope.order(:id).each_slice(batch_size).sum { call(chunks: _1).size }
    end

    def self.call(chunks:)
      return [] if chunks.empty?

      vectors = RubyLLM.embed(chunks.map(&:text)).vectors
      chunks.zip(vectors).each { |chunk, vector| chunk.update!(embedding: vector) }
      chunks
    end
  end
end
