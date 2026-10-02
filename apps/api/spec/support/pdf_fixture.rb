# Builds the smallest valid multi-page PDF that pdf-reader can parse, so
# Assemble::HandbookChunker specs don't need a binary fixture file checked
# into the repo. Page text must avoid parens/backslashes (unescaped in the
# PDF content stream).
module PdfFixture
  def self.build(page_texts)
    font_object_number = page_texts.size * 2 + 3

    objects = [ catalog_object, pages_object(page_texts.size) ]
    page_texts.each_with_index { |text, i| objects.concat(page_objects(i, text, font_object_number)) }
    objects << font_object(font_object_number)

    assemble(objects)
  end

  def self.catalog_object = "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n"

  def self.pages_object(count)
    refs = (0...count).map { |i| "#{3 + i * 2} 0 R" }.join(" ")
    "2 0 obj\n<< /Type /Pages /Kids [#{refs}] /Count #{count} >>\nendobj\n"
  end

  def self.page_objects(index, text, font_object_number)
    page_number = 3 + index * 2
    content_number = page_number + 1
    stream = "BT /F1 12 Tf 72 712 Td (#{text}) Tj ET\n"

    [
      "#{page_number} 0 obj\n<< /Type /Page /Parent 2 0 R " \
        "/Resources << /Font << /F1 #{font_object_number} 0 R >> >> " \
        "/MediaBox [0 0 612 792] /Contents #{content_number} 0 R >>\nendobj\n",
      "#{content_number} 0 obj\n<< /Length #{stream.bytesize} >>\nstream\n#{stream}endstream\nendobj\n"
    ]
  end

  def self.font_object(number) = "#{number} 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n"

  def self.assemble(objects)
    header = "%PDF-1.4\n"
    body = +""
    offsets = []
    pos = header.bytesize

    objects.each do |object|
      offsets << pos
      body << object
      pos += object.bytesize
    end

    xref_offset = header.bytesize + body.bytesize
    xref = +"xref\n0 #{objects.size + 1}\n0000000000 65535 f \n"
    offsets.each { |offset| xref << format("%010d 00000 n \n", offset) }
    trailer = "trailer\n<< /Size #{objects.size + 1} /Root 1 0 R >>\nstartxref\n#{xref_offset}\n%%EOF"

    header + body + xref + trailer
  end
end
