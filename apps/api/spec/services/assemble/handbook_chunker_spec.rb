require "rails_helper"

RSpec.describe Assemble::HandbookChunker do
  # Mirrors SPEC.md section 6, stage 3: deterministic, no LLM — paragraph-
  # boundary chunking and page tagging is plain Ruby over extracted text.
  describe ".chunks_for" do
    it "keeps a single short page as one chunk, tagged with its page number" do
      chunks = described_class.chunks_for(pages: [ "Engineers attending conferences are approved." ])

      expect(chunks).to eq([
        Assemble::HandbookChunker::ChunkData.new(page: 1, position: 0, text: "Engineers attending conferences are approved.")
      ])
    end

    it "splits a page into one chunk per paragraph when paragraphs don't fit together" do
      huge_paragraph = "A" * 1000
      page = "#{huge_paragraph}\n\n#{"B" * 1000}"

      chunks = described_class.chunks_for(pages: [ page ])

      expect(chunks.map(&:position)).to eq([ 0, 1 ])
      expect(chunks[0].text).to eq(huge_paragraph)
      expect(chunks[1].text).to eq("B" * 1000)
    end

    it "groups consecutive small paragraphs into the same chunk" do
      page = "First paragraph.\n\nSecond paragraph.\n\nThird paragraph."

      chunks = described_class.chunks_for(pages: [ page ])

      expect(chunks.size).to eq(1)
      expect(chunks.first.text).to eq("First paragraph.\n\nSecond paragraph.\n\nThird paragraph.")
    end

    it "tags chunks from different pages with their own page number, each restarting position at 0" do
      chunks = described_class.chunks_for(pages: [ "Page one text.", "Page two text." ])

      expect(chunks).to eq([
        Assemble::HandbookChunker::ChunkData.new(page: 1, position: 0, text: "Page one text."),
        Assemble::HandbookChunker::ChunkData.new(page: 2, position: 0, text: "Page two text.")
      ])
    end

    it "ignores blank pages" do
      expect(described_class.chunks_for(pages: [ "", "  \n\n  " ])).to eq([])
    end
  end

  describe ".call" do
    def pdf_with(page_texts)
      PdfFixture.build(page_texts)
    end

    it "extracts, chunks and persists the attached PDF's text, and records the page count" do
      document = create(:source_document)
      document.file.attach(
        io: StringIO.new(pdf_with([ "Engineers attending conferences are approved." ])),
        filename: "handbook.pdf", content_type: "application/pdf"
      )

      chunks = described_class.call(source_document: document)

      expect(chunks.size).to eq(1)
      expect(chunks.first).to be_a(Chunk)
      expect(chunks.first).to have_attributes(page: 1, position: 0, text: "Engineers attending conferences are approved.")
      expect(document.reload.page_count).to eq(1)
      expect(document.chunks.count).to eq(1)
    end
  end
end
