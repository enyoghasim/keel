module Assemble
  # Stage 3 of the Assemble pipeline (SPEC.md section 6): extracts text per
  # page with pdf-reader and splits it into ~400-token chunks on paragraph
  # boundaries, each tagged with its page number. Deterministic — no LLM
  # involved; embedding the chunks is a separate step.
  class HandbookChunker
    TARGET_CHARS = 1600 # ~400 tokens at ~4 chars/token; no tokenizer dependency

    ChunkData = Data.define(:page, :position, :text)

    def self.call(source_document:)
      pages = extract_pages(source_document.file.download)
      source_document.update!(page_count: pages.size)

      chunks_for(pages: pages).map do |c|
        Chunk.create!(source_document: source_document, page: c.page, position: c.position, text: c.text)
      end
    end

    def self.chunks_for(pages:)
      pages.each_with_index.flat_map { |text, i| chunk_page(text, page: i + 1) }
    end

    def self.extract_pages(pdf_bytes)
      PDF::Reader.new(StringIO.new(pdf_bytes)).pages.map(&:text)
    end
    private_class_method :extract_pages

    def self.chunk_page(text, page:)
      group_paragraphs(paragraphs_of(text)).each_with_index.map do |group, position|
        ChunkData.new(page: page, position: position, text: group.join("\n\n"))
      end
    end
    private_class_method :chunk_page

    def self.paragraphs_of(text)
      text.to_s.split(/\n{2,}/).map(&:strip).reject(&:empty?)
    end
    private_class_method :paragraphs_of

    def self.group_paragraphs(paragraphs)
      groups = []
      current = []
      current_size = 0

      paragraphs.each do |paragraph|
        if current.any? && current_size + paragraph.length > TARGET_CHARS
          groups << current
          current = []
          current_size = 0
        end

        current << paragraph
        current_size += paragraph.length
      end

      groups << current if current.any?
      groups
    end
    private_class_method :group_paragraphs
  end
end
