namespace :handbook do
  desc "Embed handbook chunks that have no embedding yet, so search_handbook can use vector search (needs OPENAI_API_KEY)"
  task embed: :environment do
    if Assemble::ChunkEmbedder.available?
      puts "Embedded #{Assemble::ChunkEmbedder.embed_missing} chunks."
    else
      puts "No embedding model configured (set OPENAI_API_KEY); search_handbook falls back to keyword search."
    end
  end
end
