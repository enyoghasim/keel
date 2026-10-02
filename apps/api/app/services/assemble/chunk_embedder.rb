module Assemble
  # The embedding half of stage 3 (SPEC.md section 6): one batched
  # RubyLLM.embed call for every chunk's text, saved into the pgvector
  # column. Kept separate from HandbookChunker so the chunking algorithm
  # stays testable without mocking the LLM.
  class ChunkEmbedder
    def self.call(chunks:)
      return [] if chunks.empty?

      vectors = RubyLLM.embed(chunks.map(&:text)).vectors
      chunks.zip(vectors).each { |chunk, vector| chunk.update!(embedding: vector) }
      chunks
    end
  end
end
