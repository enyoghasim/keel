module Agent
  module Tools
    # A tool the agent can call (SPEC.md section 9): a name, a description
    # written for the model, a JSON Schema for its arguments, and #execute,
    # which wraps one deterministic service and returns a Hash. The model
    # only ever sees the result as JSON; errors come back as {"error": ...}
    # so the model can explain or recover instead of the run crashing.
    class Base < RubyLLM::Tool
      class PermissionError < StandardError; end

      REQUEST_KINDS = %w[expense leave equipment].freeze

      # The payload fields Rules::Engine understands (the policy-rules
      # schema's whitelist), so the model can't invent one.
      PAYLOAD_SCHEMA = {
        type: "object",
        additionalProperties: false,
        properties: {
          amount_eur: { type: "number", description: "Amount in euros, for expenses and equipment" },
          category: { type: "string", description: "Expense category, e.g. conference, travel, meals" },
          days: { type: "number", description: "Number of leave days" },
          notice_days: { type: "number", description: "Days of notice before the leave starts" }
        }
      }.freeze

      def self.tool_name(value = nil)
        value ? @tool_name = value : @tool_name
      end

      def initialize(context)
        super()
        @context = context
      end

      def name = self.class.tool_name

      def call(args)
        result = super
        (result.is_a?(Hash) ? result : { "result" => result }).to_json
      rescue PermissionError => e
        { "error" => e.message }.to_json
      rescue StandardError => e
        { "error" => "#{e.class.name.demodulize}: #{e.message}" }.to_json
      end

      private

      attr_reader :context

      # Write tools that change the org or its rules are for hr_admin only
      # (SPEC.md section 9); the model gets the refusal as a normal error.
      def require_hr_admin!(action)
        raise PermissionError, "Only people with the hr_admin role can #{action}." unless person.hr_admin?
      end

      def company = context.company
      def person = context.person

      def person_summary(record)
        return nil if record.nil?

        {
          "id" => record.id, "name" => record.name, "title" => record.title,
          "department" => record.department&.name, "department_id" => record.department_id
        }
      end
    end
  end
end
