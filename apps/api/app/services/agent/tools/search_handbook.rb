module Agent
  module Tools
    # Looks up what the handbook says (SPEC.md section 9): pgvector search
    # over the company's chunks, returning verbatim quotes with page numbers
    # so answers can cite them. Seeded handbooks have no embeddings and an
    # install may have no model key, so it degrades to keyword search —
    # reporting which mode ran — instead of failing the run.
    class SearchHandbook < Base
      LIMIT = 5
      STOPWORDS = %w[the and for how what many much who when are can does with that this from have has about].freeze

      tool_name "search_handbook"
      description "Search the company handbook and return the most relevant passages as quotes with page numbers. " \
                  "Use it to cite what the handbook says, e.g. when explaining a policy decision."
      params({
        type: "object", additionalProperties: false, required: [ "query" ],
        properties: { query: { type: "string", description: "What to look for, in plain language" } }
      })

      def execute(query:)
        chunks = semantic(query)
        mode = chunks ? "semantic" : "keyword"
        chunks ||= keyword(query)

        { "mode" => mode, "results" => chunks.map { quote(_1) } }
      end

      private

      def handbook = Chunk.joins(:source_document).where(source_documents: { company_id: company.id })

      # nil when vector search isn't possible, so the caller falls back.
      def semantic(query)
        return nil unless Assemble::ChunkEmbedder.available? && handbook.where.not(embedding: nil).exists?

        vector = RubyLLM.embed(query).vectors
        handbook.includes(:source_document).nearest_neighbors(:embedding, vector, distance: "cosine").first(LIMIT)
      rescue RubyLLM::Error => e
        Rails.logger.warn("[Agent::Tools::SearchHandbook] embedding failed, using keywords: #{e.message}")
        nil
      end

      def keyword(query)
        words = query.downcase.scan(/[[:alnum:]]{3,}/).uniq - STOPWORDS
        scored = handbook.includes(:source_document).filter_map do |chunk|
          text = chunk.text.downcase
          score = words.count { text.include?(_1) }
          [ score, chunk ] if score.positive?
        end

        scored.sort_by { |score, chunk| [ -score, chunk.page, chunk.position ] }.first(LIMIT).map(&:last)
      end

      def quote(chunk)
        { "quote" => chunk.text, "page" => chunk.page, "document" => chunk.source_document.filename, "chunk_id" => chunk.id }
      end
    end
  end
end
