module Seeds
  # The Demo Factorial handbook (factorial_handbook.pdf, SPEC.md section 16) as the chunks
  # Assemble would have produced, the policies and rules extracted from it,
  # and the workflows generated around them. The handbook plants specific
  # situations on purpose:
  #
  # * clear thresholds (expenses over €500 / €2,000, 14 days' leave notice)
  # * two ambiguities (conference allowance, remote work) — their rules stay
  #   `extracted`/`needs_review` until a human resolves them, so the engine
  #   doesn't enforce a guess
  # * one conflict: travel under €800 auto-approves, contradicting the €500
  #   expense rule (same priority, so Rules::ConflictDetector flags it)
  # * a company-history paragraph with numbers but no rules
  #
  # Chunks have no embedding: seeding must not need a model key.
  module FactorialHandbook
    CHUNKS = {
      history: [ 1, "About Demo Factorial. Demo Factorial was founded in 2016 in Barcelona by Marc Vidal to help " \
        "growing companies manage their people from one place. Today our product and go-to-market teams work out of " \
        "Barcelona, Madrid and Lisbon, and we have grown from 4 people to 28. We are proud of our 4.8 customer rating." ],
      leave: [ 2, "Leave. Every employee has 20 days of paid annual leave. Leave of 3 days or fewer is approved automatically. " \
        "Leave of more than 3 days needs your manager's approval, and must be requested with 14 days' notice for more than 3 days; " \
        "requests with less notice are declined." ],
      remote: [ 3, "Remote work. Remote work is generally allowed two days a week. Teams agree their office days together, " \
        "and warehouse roles are always on site." ],
      expenses: [ 4, "Expenses. Expenses of €500 or less are approved automatically. Expenses over €500 need your manager's approval. " \
        "Expenses over €2,000 also need the finance lead's approval. " \
        "Engineers attending conferences are automatically approved up to €1,000." ],
      travel: [ 5, "Travel. Business travel under €800 is approved automatically when booked through the company travel portal. " \
        "Book at least a week ahead where you can." ],
      equipment: [ 5, "Equipment. Equipment up to €1,500 needs your manager's approval and is ordered by IT. " \
        "Equipment over €1,500 also needs the finance lead's approval." ],
      onboarding: [ 6, "Onboarding. New joiners get a laptop and accounts on their first day, and a buddy for their first month." ]
    }.freeze

    manager = "manager_of(requester)"
    finance = "role:finance_lead"

    # [policy category, status, rules]. A rule is
    # [key, priority, status, conditions, actions, chunk, quote, ambiguities].
    POLICIES = {
      "leave" => [ "active", [
        [ "leave_short_auto", 1, "active", { "field" => "payload.days", "op" => "lte", "value" => 3 }, { "decision" => "auto_approve" },
          :leave, "Leave of 3 days or fewer is approved automatically.", [] ],
        [ "leave_long_manager", 1, "active", { "field" => "payload.days", "op" => "gt", "value" => 3 },
          { "decision" => "require_approval", "approvers" => [ manager ] },
          :leave, "Leave of more than 3 days needs your manager's approval", [] ],
        [ "leave_notice_14_days", 2, "active",
          { "all" => [ { "field" => "payload.days", "op" => "gt", "value" => 3 }, { "field" => "payload.notice_days", "op" => "lt", "value" => 14 } ] },
          { "decision" => "reject", "reason" => "Leave of more than 3 days needs 14 days' notice." },
          :leave, "must be requested with 14 days' notice for more than 3 days", [] ]
      ] ],
      "expense" => [ "active", [
        [ "expense_under_500_auto", 1, "active", { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 }, { "decision" => "auto_approve" },
          :expenses, "Expenses of €500 or less are approved automatically.", [] ],
        [ "expense_over_500_manager", 1, "active", { "field" => "payload.amount_eur", "op" => "gt", "value" => 500 },
          { "decision" => "require_approval", "approvers" => [ manager ] },
          :expenses, "Expenses over €500 need your manager's approval.", [] ],
        [ "expense_over_2000_finance", 2, "active", { "field" => "payload.amount_eur", "op" => "gt", "value" => 2000 },
          { "decision" => "require_approval", "approvers" => [ manager, finance ] },
          :expenses, "Expenses over €2,000 also need the finance lead's approval.", [] ],
        [ "expense_conference_engineering", 3, "extracted",
          { "all" => [ { "field" => "requester.department", "op" => "eq", "value" => "Engineering" },
                       { "field" => "payload.category", "op" => "eq", "value" => "conference" },
                       { "field" => "payload.amount_eur", "op" => "lte", "value" => 1000 } ] },
          { "decision" => "auto_approve" },
          :expenses, "Engineers attending conferences are automatically approved up to €1,000.",
          [ { "phrase" => "attending conferences", "question" => "Does the €1,000 cover travel and hotel, or only the ticket?",
              "options" => [ "Ticket only", "Ticket, travel and hotel" ] } ] ],
        [ "expense_travel_under_800_auto", 1, "active",
          { "all" => [ { "field" => "payload.category", "op" => "eq", "value" => "travel" }, { "field" => "payload.amount_eur", "op" => "lt", "value" => 800 } ] },
          { "decision" => "auto_approve" },
          :travel, "Business travel under €800 is approved automatically", [] ]
      ] ],
      "remote" => [ "needs_review", [
        [ "remote_two_days", 1, "extracted", { "field" => "payload.days", "op" => "lte", "value" => 2 }, { "decision" => "auto_approve" },
          :remote, "Remote work is generally allowed two days a week.",
          [ { "phrase" => "generally allowed", "question" => "Is two days a hard cap, or can a manager approve more?",
              "options" => [ "Hard cap of two days", "Manager can approve more" ] } ] ]
      ] ],
      "equipment" => [ "active", [
        [ "equipment_standard_manager", 1, "active", { "field" => "payload.amount_eur", "op" => "lte", "value" => 1500 },
          { "decision" => "require_approval", "approvers" => [ manager ] },
          :equipment, "Equipment up to €1,500 needs your manager's approval", [] ],
        [ "equipment_over_1500_finance", 2, "active", { "field" => "payload.amount_eur", "op" => "gt", "value" => 1500 },
          { "decision" => "require_approval", "approvers" => [ manager, finance ] },
          :equipment, "Equipment over €1,500 also needs the finance lead's approval.", [] ]
      ] ],
      "onboarding" => [ "draft", [] ]
    }.freeze

    WORKFLOWS = {
      "leave" => [
        { "key" => "approval", "type" => "approval", "assignee" => "manager_of(requester)" },
        { "key" => "hr_notify", "type" => "notify", "assignee" => "role:hr_admin" }
      ],
      "expense" => [
        { "key" => "approval", "type" => "approval", "assignee" => "manager_of(requester)" },
        { "key" => "finance_notify", "type" => "notify", "assignee" => "role:finance_lead",
          "when" => { "field" => "payload.amount_eur", "op" => "gt", "value" => 1000 } }
      ],
      "equipment" => [
        { "key" => "approval", "type" => "approval", "assignee" => "manager_of(requester)" },
        { "key" => "it_order", "type" => "task", "assignee" => "role:it_admin", "title" => "Order the equipment" },
        { "key" => "finance_notify", "type" => "notify", "assignee" => "role:finance_lead",
          "when" => { "field" => "payload.amount_eur", "op" => "gt", "value" => 1500 } }
      ]
    }.freeze

    def self.call(company)
      document = company.source_documents.create!(filename: "factorial_handbook.pdf", kind: "handbook", page_count: 6)
      chunks = CHUNKS.each_with_index.to_h do |(key, (page, text)), position|
        [ key, document.chunks.create!(page: page, position: position, text: text) ]
      end

      POLICIES.each do |category, (status, rules)|
        policy = company.policies.create!(title: "#{category.titleize} Policy", category: category, status: status)
        rules.each do |key, priority, rule_status, conditions, actions, chunk, quote, ambiguities|
          policy.rules.create!(key: key, priority: priority, status: rule_status, conditions: conditions, actions: actions,
                               source_chunk: chunks.fetch(chunk), source_quote: quote, ambiguities: ambiguities)
        end
      end

      WORKFLOWS.each do |kind, steps|
        company.workflows.create!(name: "#{kind.titleize} Workflow", trigger: { "request_kind" => kind }, steps: steps, status: "active")
      end
    end
  end
end
