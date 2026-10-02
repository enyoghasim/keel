module Agent
  # The agent loop (SPEC.md section 9). The model only chooses tools and
  # explains their results; every fact and every decision comes from a
  # tool wrapping a deterministic service. ruby_llm runs the tool-calling
  # loop itself — this class sets it up as the signed-in person, records
  # every model reply and tool call as an AgentStep through ruby_llm's
  # callbacks (the trace AGENTS.md rule 3 requires), and stops a run that
  # won't converge.
  class Runner
    class TooManyTurns < StandardError; end

    MAX_TURNS = 8
    # How many earlier question-and-answer pairs of a conversation the model sees.
    HISTORY_TURNS = 5
    TOOLS = [
      Tools::SearchPeople, Tools::OrgLookup, Tools::CheckPolicy, Tools::WhoApproves,
      Tools::CreateRequest, Tools::ListMyRequests, Tools::RunInsight, Tools::SearchHandbook
    ].freeze
    # Only an hr_admin can propose org or policy changes (SPEC.md section 9);
    # the tools check this too, so a model can't talk its way around it.
    HR_ADMIN_TOOLS = [ Tools::ProposeOrgChange, Tools::ProposeRuleChange ].freeze

    def self.call(agent_run, &on_step) = new(agent_run, on_step).call

    def initialize(agent_run, on_step)
      @agent_run = agent_run
      @on_step = on_step
      @position = 0
      @turns = 0
    end

    def call
      @agent_run.update!(status: "running")
      context = Context.new(company: @agent_run.company, person: @agent_run.person, agent_run: @agent_run)
      chat = RubyLLM.chat.with_instructions(instructions).with_tools(*tools.map { _1.new(context) })
      replay_history(chat)
      record_steps(chat)

      reply = chat.ask(@agent_run.message)
      @agent_run.update!(status: "completed", final_text: reply.content, total_tokens: @agent_run.agent_steps.sum(:tokens))
    rescue TooManyTurns
      fail!("Stopped after #{MAX_TURNS} model turns without a final answer.")
    rescue StandardError => e
      Rails.logger.error("[Agent::Runner] #{e.class}: #{e.message}")
      fail!("#{e.class}: #{e.message}")
    end

    private

    def tools = @agent_run.person.hr_admin? ? TOOLS + HR_ADMIN_TOOLS : TOOLS

    # Earlier turns of the conversation go back in as plain questions and
    # answers only — not their tool calls — so a follow-up like "and what
    # about €2,000?" has its context while each run's trace stays its own.
    def replay_history(chat)
      @agent_run.previous_turns(HISTORY_TURNS).each do |turn|
        chat.add_message(role: :user, content: turn.message)
        chat.add_message(role: :assistant, content: turn.final_text)
      end
    end

    def record_steps(chat)
      chat.before_message { @started = now }
      chat.after_message do |message|
        next unless message.role == :assistant

        record!(kind: "llm", tokens: message.input_tokens.to_i + message.output_tokens.to_i,
          output: { "content" => message.content.to_s, "tool_calls" => tool_calls_of(message) }.compact)
        @turns += 1 if message.tool_call?
        raise TooManyTurns if @turns >= MAX_TURNS
      end
      chat.before_tool_call do |tool_call|
        @tool_call = tool_call
        @started = now
      end
      chat.after_tool_result do |result|
        record!(kind: "tool", tool_name: @tool_call.name, input: @tool_call.arguments, output: parse(result))
      end
    end

    def record!(**attrs)
      step = @agent_run.agent_steps.create!(position: @position += 1, latency_ms: ((now - @started) * 1000).round, **attrs)
      @on_step&.call(step)
    end

    def fail!(message)
      @agent_run.update!(status: "failed", error_message: message, total_tokens: @agent_run.agent_steps.sum(:tokens))
    end

    def tool_calls_of(message)
      return nil unless message.tool_call?

      message.tool_calls.values.map { { "name" => _1.name, "arguments" => _1.arguments } }
    end

    def parse(result)
      JSON.parse(result.to_s)
    rescue JSON::ParserError
      { "result" => result.to_s }
    end

    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    def instructions
      person = @agent_run.person

      <<~PROMPT
        You are Keel, the operating assistant for #{@agent_run.company.name}. You are acting for
        #{person.name} (#{[ person.title, person.department&.name ].compact.join(', ')}; manager:
        #{person.manager&.name || 'none'}; roles: #{person.roles.presence&.join(', ') || 'none'}).
        "I", "me" and "my" mean #{person.name}. Today is #{Date.current.iso8601}.

        Rules:
        - Always use tools for facts about people, policies, requests and numbers. Never guess.
        - Never state a policy outcome without calling check_policy first, and cite the handbook
          page it returns when there is one.
        - Use who_approves for "who approves…" or "who is it waiting on" questions about a future request, and
          list_my_requests for the status of requests already submitted.
        - Only call create_request when the person clearly asks to submit something. Never claim a
          request was submitted, approved or changed unless a tool result says so.
        - Use search_handbook to quote what the handbook says, and cite the page.
        - propose_org_change and propose_rule_change only record a proposal that a person must approve:
          a proposal is not a change. Say it is waiting for approval, summarise its impact, and point to
          the Proposals page (/proposals). Never say the org or a policy was changed.
        - If a tool returns an error, explain it plainly instead of retrying the same call.
        - Keep answers short and plain: the person is an employee, not an engineer.
      PROMPT
    end
  end
end
