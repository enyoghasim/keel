module Insights
  # Runs an insight-query object (SPEC.md section 11) through ActiveRecord.
  # No LLM: Insights::Interpreter only fills in the query object, and this
  # is the only place that turns it into SQL. Every metric, group-by and
  # filter field maps to a hand-written SQL fragment from the constants
  # below — nothing from the query object is ever interpolated, only bound
  # as a value — and every query is scoped to the one company.
  class QueryBuilder
    class InvalidQuery < StandardError; end

    Row = Data.define(:key, :label, :value)
    Result = Data.define(:rows, :unit, :summary)

    DECIDED = %w[approved rejected].freeze
    DEFAULT_LIMIT = 25

    # Approval steps are the ones Workflows::Runtime creates with a
    # person:<id> reference; the approver is known from it even before the
    # step becomes active and resolved_person_id is filled in.
    APPROVAL_STEPS_JOIN = <<~SQL.squish.freeze
      INNER JOIN workflow_runs ON workflow_runs.request_id = requests.id
      INNER JOIN step_runs approval_steps ON approval_steps.workflow_run_id = workflow_runs.id
        AND approval_steps.reference LIKE 'person:%'
        AND approval_steps.status IN ('pending', 'done', 'rejected')
      INNER JOIN people approvers ON approvers.id =
        COALESCE(approval_steps.resolved_person_id, CAST(SUBSTRING(approval_steps.reference FROM 8) AS bigint))
      LEFT JOIN departments approver_departments ON approver_departments.id = approvers.department_id
    SQL

    DECISION_TIME_JOIN = <<~SQL.squish.freeze
      INNER JOIN LATERAL (
        SELECT MAX(step_runs.acted_at) AS decided_at
        FROM workflow_runs INNER JOIN step_runs ON step_runs.workflow_run_id = workflow_runs.id
        WHERE workflow_runs.request_id = requests.id
      ) decisions ON decisions.decided_at IS NOT NULL
    SQL

    OVERRIDDEN = <<~SQL.squish.freeze
      EXISTS (
        SELECT 1 FROM workflow_runs INNER JOIN step_runs ON step_runs.workflow_run_id = workflow_runs.id
        WHERE workflow_runs.request_id = requests.id AND step_runs.overridden
      )
    SQL

    METRICS = {
      "request_count" => {
        name: "Request count", unit: "count", noun: "request",
        value: "COUNT(DISTINCT requests.id)",
        group_by: %w[department kind month decision]
      },
      "leave_days" => {
        name: "Leave days", unit: "days",
        where: { kind: "leave", status: "approved" },
        value: "SUM(CAST(requests.payload->>'days' AS numeric))",
        group_by: %w[department person month]
      },
      "expense_total" => {
        name: "Expense total", unit: "eur",
        where: { kind: "expense", status: "approved" },
        value: "SUM(CAST(requests.payload->>'amount_eur' AS numeric))",
        group_by: %w[department category month]
      },
      "approval_load" => {
        name: "Approval load", unit: "count", noun: "approval step",
        join: APPROVAL_STEPS_JOIN,
        value: "COUNT(approval_steps.id)",
        group_by: %w[approver department]
      },
      "time_to_decision" => {
        name: "Time to decision", unit: "hours",
        where: { status: DECIDED },
        join: DECISION_TIME_JOIN,
        value: "percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM decisions.decided_at - requests.created_at) / 3600.0)",
        group_by: %w[department kind]
      },
      "override_rate" => {
        name: "Override rate", unit: "percent",
        where: { status: DECIDED },
        value: "100.0 * AVG(CASE WHEN #{OVERRIDDEN} THEN 1 ELSE 0 END)",
        group_by: %w[rule policy month]
      },
      "auto_approval_rate" => {
        name: "Auto-approval rate", unit: "percent",
        value: "100.0 * AVG(CASE WHEN requests.decision = 'auto_approve' THEN 1 ELSE 0 END)",
        group_by: %w[policy month]
      }
    }.freeze

    MONTH = "to_char(date_trunc('month', requests.created_at), 'YYYY-MM')".freeze

    # key and label are separate so two people (or departments) with the
    # same name stay two rows.
    GROUPS = {
      "department" => { key: "departments.id", label: "departments.name", none: "No department" },
      "kind" => { key: "requests.kind", label: "requests.kind" },
      "month" => { key: MONTH, label: MONTH },
      "decision" => { key: "requests.decision", label: "requests.decision", none: "Undecided" },
      "person" => { key: "requesters.id", label: "requesters.name" },
      "category" => { key: "requests.payload->>'category'", label: "requests.payload->>'category'", none: "Uncategorised" },
      "approver" => { key: "approvers.id", label: "approvers.name" },
      "rule" => {
        key: "matched_rule.key", label: "matched_rule.key",
        join: "CROSS JOIN LATERAL unnest(requests.matched_rule_ids) AS matched_rule(key)"
      },
      "policy" => {
        key: "policies.id", label: "policies.title", none: "No policy",
        join: "LEFT JOIN policies ON policies.company_id = requests.company_id " \
              "AND policies.category = requests.kind AND policies.status = 'active'"
      }
    }.freeze

    # Approval load is about the approver, so "by department" means theirs.
    APPROVER_DEPARTMENT = { key: "approver_departments.id", label: "approver_departments.name", none: "No department" }.freeze

    FILTER_COLUMNS = {
      "request.kind" => "requests.kind",
      "request.decision" => "requests.decision",
      "request.status" => "requests.status",
      "requester.department" => "departments.name",
      "payload.category" => "requests.payload->>'category'"
    }.freeze

    def self.call(company:, query:) = new(company, query).call

    def initialize(company, query)
      @company = company
      @query = query.to_h.deep_stringify_keys
    end

    def call
      validate!
      rows = sort(fetch_rows)
      total_groups = rows.size
      rows = rows.first(@query.fetch("limit", DEFAULT_LIMIT)) unless month?

      Result.new(rows: rows, unit: metric[:unit], summary: summarize(rows, total_groups))
    end

    private

    def metric = METRICS.fetch(@query["metric"])
    def group_by = @query["group_by"]
    def month? = group_by == "month"

    def group
      return APPROVER_DEPARTMENT if group_by == "department" && @query["metric"] == "approval_load"

      GROUPS.fetch(group_by)
    end

    def validate!
      errors = JSONSchemer.schema(Llm::SchemaRegistry.fetch("insight-query")).validate({ "query" => @query }).to_a
      if errors.any?
        detail = errors.map { JSONSchemer::Errors.pretty(_1) }.join("; ")
        raise InvalidQuery, "Insights can't run that query (#{detail}). Available metrics: #{METRICS.keys.join(', ')}."
      end

      return if group_by.nil? || metric[:group_by].include?(group_by)

      raise InvalidQuery, "#{metric[:name]} can't be grouped by #{group_by}. Try: #{metric[:group_by].join(', ')}."
    end

    def fetch_rows
      scope = filtered_scope
      value = Arel.sql(metric[:value])
      return [ Row.new(key: nil, label: "Total", value: round(scope.pick(value))) ].reject { _1.value.nil? } if group_by.nil?

      scope = scope.joins(group[:join]) if group[:join]
      key = Arel.sql(group[:key])
      label = Arel.sql(group[:label])

      scope.group(key, label).pluck(key, label, value).map do |k, l, v|
        Row.new(key: k, label: month? ? Date.strptime(l, "%Y-%m").strftime("%b %Y") : (l || group.fetch(:none, "None")), value: round(v))
      end
    end

    def filtered_scope
      scope = Request.where(company_id: @company.id)
                     .joins("INNER JOIN people requesters ON requesters.id = requests.requester_id")
                     .joins("LEFT JOIN departments ON departments.id = requesters.department_id")
      scope = scope.where(metric[:where]) if metric[:where]
      scope = scope.joins(metric[:join]) if metric[:join]
      scope = apply_time_range(scope)

      @query.fetch("filters", []).reduce(scope) { |s, filter| apply_filter(s, filter) }
    end

    def apply_time_range(scope)
      range = @query["time_range"]
      return scope if range.nil?

      from = Date.iso8601(range.fetch("from"))
      to = Date.iso8601(range.fetch("to"))
      scope.where("requests.created_at >= ? AND requests.created_at < ?", from.beginning_of_day, (to + 1).beginning_of_day)
    rescue Date::Error
      raise InvalidQuery, "The time range #{range.inspect} isn't a pair of valid dates."
    end

    def apply_filter(scope, filter)
      column = FILTER_COLUMNS.fetch(filter["field"])
      values = Array(filter["value"])

      case filter["op"]
      when "eq", "in" then scope.where("#{column} IN (?)", values)
      when "neq" then scope.where("#{column} IS NULL OR #{column} NOT IN (?)", values)
      end
    end

    def sort(rows)
      return rows.sort_by(&:key) if month?

      direction = @query["sort"] == "asc" ? 1 : -1
      rows.sort_by { [ direction * _1.value, _1.label.to_s ] }
    end

    def round(value) = value&.to_f&.round(2)

    def summarize(rows, total_groups)
      return "No matching data for this question." if rows.empty?
      return "Overall: #{format_value(rows.first.value)}." if group_by.nil?

      top = rows.max_by(&:value)
      "#{top.label} is highest with #{format_value(top.value)}, out of #{total_groups} #{group_by.pluralize(total_groups)}.".upcase_first
    end

    def format_value(value)
      number = ActiveSupport::NumberHelper.number_to_delimited(value % 1 == 0 ? value.to_i : value)

      case metric[:unit]
      when "count" then "#{number} #{metric[:noun].pluralize(value)}"
      when "days" then "#{number} #{'day'.pluralize(value)}"
      when "hours" then "#{number} #{'hour'.pluralize(value)}"
      when "eur" then "€#{number}"
      when "percent" then "#{number}%"
      end
    end
  end
end
