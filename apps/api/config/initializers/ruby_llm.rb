RubyLLM.configure do |config|
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.default_model = "gpt-5.1"
  # default_embedding_model is ruby_llm's own default (text-embedding-3-small,
  # 1536 dimensions) — matches the chunks.embedding column from SPEC.md
  # section 4, so there's nothing to override here.
end
