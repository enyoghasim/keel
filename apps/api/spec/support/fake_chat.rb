# Stands in for RubyLLM::Chat in Agent::Runner specs. Replays a scripted
# conversation through the same callback sequence ruby_llm's tool loop
# uses (before_message → after_message for each model reply;
# before_tool_call → after_tool_result around each tool, which really
# executes against the registered tool instance), so the runner's trace
# recording is tested against the gem's contract, not a guess at it.
class FakeChat
  attr_reader :instructions, :tools, :asked, :history

  # turns: [{ tool_calls: [{ name:, arguments: }], tokens: [in, out] }, ..., { content: "final", tokens: [in, out] }]
  # A turn may also carry model: "gpt-5.1", so ruby_llm can price its tokens.
  def initialize(turns)
    @turns = turns
    @tools = {}
    @history = []
    @callbacks = Hash.new { |h, k| h[k] = [] }
  end

  def with_instructions(text) = tap { @instructions = text }
  # Earlier turns replayed before ask, as [role, content] pairs.
  def add_message(attrs) = tap { @history << [ attrs[:role], attrs[:content] ] }
  def with_tools(*tools) = tap { tools.each { |t| @tools[t.name] = t } }

  %i[before_message after_message before_tool_call after_tool_result].each do |name|
    define_method(name) { |&block| tap { @callbacks[name] << block } }
  end

  # A turn with plain content may also carry chunks: ["Ye", "s, but ..."] to
  # script how the streaming block receives it piece by piece; without it,
  # the whole content is yielded as a single chunk.
  def ask(message, &block)
    @asked = message
    @turns.each_with_index do |turn, i|
      run(:before_message)
      tokens = turn.fetch(:tokens, [ 100, 20 ])

      if turn[:tool_calls]
        calls = turn[:tool_calls].each_with_index.to_h do |call, j|
          [ "call_#{i}_#{j}", RubyLLM::ToolCall.new(id: "call_#{i}_#{j}", name: call[:name], arguments: call[:arguments]) ]
        end
        run(:after_message, RubyLLM::Message.new(role: :assistant, content: "", tool_calls: calls, input_tokens: tokens[0], output_tokens: tokens[1], model_id: turn[:model]))

        calls.each_value do |tool_call|
          run(:before_message)
          run(:before_tool_call, tool_call)
          tool = @tools.fetch(tool_call.name)
          result = tool.call(tool_call.arguments)
          run(:after_tool_result, result)
          run(:after_message, RubyLLM::Message.new(role: :tool, content: result, tool_call_id: tool_call.id))
        end
      else
        content = turn.fetch(:content)
        (turn[:chunks] || [ content ]).each { |piece| block&.call(RubyLLM::Chunk.new(role: :assistant, content: piece)) }
        reply = RubyLLM::Message.new(role: :assistant, content: content, input_tokens: tokens[0], output_tokens: tokens[1], model_id: turn[:model])
        run(:after_message, reply)
        return reply
      end
    end
    raise "FakeChat script ended without a final answer"
  end

  private

  def run(name, *args) = @callbacks[name].each { _1.call(*args) }
end
