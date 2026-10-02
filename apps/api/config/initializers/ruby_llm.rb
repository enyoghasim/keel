RubyLLM.configure do |config|
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.default_model = "claude-sonnet-4-5"
end
