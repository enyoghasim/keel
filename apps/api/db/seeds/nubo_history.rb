module Seeds
  # Three months (July to September 2026) of past requests, submitted
  # through the real Workflows::Submission and approved step by step
  # through Workflows::Runtime, so every decision, matched rule and routed
  # approver is what the engine actually produces. Only the clock is
  # faked: timestamps are moved back to when each request would have
  # happened, with randomised approval times. About 5% of decided
  # requests carry an override with a plausible reason; the final days
  # are left pending so the Inbox has live work.
  module NuboHistory
    PERIOD = (Time.utc(2026, 7, 1)...Time.utc(2026, 10, 1)).freeze
    PENDING_AFTER = Time.utc(2026, 9, 28)
    VOLUME = { "expense" => 400, "leave" => 150, "equipment" => 30 }.freeze
    OVERRIDE_RATE = 0.05
    REJECT_RATE = 0.04

    EXPENSE_CATEGORIES = { "travel" => 3, "meals" => 3, "software" => 2, "office" => 2, "training" => 1, "conference" => 1 }.freeze
    EQUIPMENT_ITEMS = [ [ "Laptop", 1_400 ], [ "Monitor", 320 ], [ "Headset", 140 ], [ "Docking station", 210 ], [ "Warehouse scanner", 1_850 ], [ "Standing desk", 480 ] ].freeze
    OVERRIDE_REASONS = [
      "Approved by the COO in a hallway conversation; policy didn't anticipate this.",
      "Customer deadline made the notice period impossible.",
      "Corrected an engine decision: the expense was pre-agreed in the budget.",
      "One-off exception for the Barcelona offsite.",
      "Manager confirmed the purchase was already approved last quarter.",
      "Duplicate of an earlier request that was already paid."
    ].freeze

    def self.call(company)
      rng = Random.new(2026)
      snapshot = Org::GraphSnapshot.load(company)
      runtime = Workflows::Runtime.new(snapshot)
      requesters = company.people.where.not(manager_id: nil).to_a

      plan = VOLUME.flat_map { |kind, count| Array.new(count) { [ random_time(rng), kind ] } }.sort_by(&:first)

      plan.each do |created_at, kind|
        request = Workflows::Submission.call(company: company, requester: requesters.sample(random: rng), kind: kind, payload: payload_for(kind, rng))
        settle(runtime, request, created_at, rng)
      end
    end

    # Weekday, working hours, roughly uniform across the period.
    def self.random_time(rng)
      loop do
        time = PERIOD.begin + rng.rand(0...(PERIOD.end - PERIOD.begin)).to_i
        next if time.saturday? || time.sunday?

        return time.change(hour: rng.rand(8..17), min: rng.rand(0..59))
      end
    end
    private_class_method :random_time

    def self.payload_for(kind, rng)
      case kind
      when "expense"
        category = EXPENSE_CATEGORIES.flat_map { |name, weight| [ name ] * weight }.sample(random: rng)
        { "amount_eur" => expense_amount(rng), "category" => category, "description" => "#{category.capitalize} expense" }
      when "leave"
        days = [ 1, 1, 2, 3, 3, 4, 5, 5, 7, 10, 14 ].sample(random: rng)
        { "days" => days, "notice_days" => [ 0, 2, 7, 14, 14, 21, 30, 45 ].sample(random: rng), "leave_type" => "annual" }
      else
        item, price = EQUIPMENT_ITEMS.sample(random: rng)
        { "amount_eur" => (price * rng.rand(0.85..1.15)).round, "item" => item }
      end
    end
    private_class_method :payload_for

    # Log-normal around €170: most land in €50-€400, a thin tail passes €1,000.
    def self.expense_amount(rng)
      gauss = Math.sqrt(-2 * Math.log(1 - rng.rand)) * Math.cos(2 * Math::PI * rng.rand)
      (Math.exp(Math.log(170) + 0.95 * gauss).clamp(50, 6_000) / 5).round * 5
    end
    private_class_method :expense_amount

    # Moves the freshly-submitted request back in time, then plays out
    # its approval steps with randomised delays.
    def self.settle(runtime, request, created_at, rng)
      workflow_run = request.workflow_run
      clock = created_at
      stamp(request, workflow_run, created_at)

      pending_tail = created_at >= PENDING_AFTER
      loop do
        step_run = workflow_run.step_runs.where(status: "pending").order(:id).first
        break if step_run.nil? || pending_tail

        clock += rng.rand(30..(60 * 36)).minutes
        runtime.act(step_run, action: step_run.reference&.start_with?("role:") ? "complete" : "approve")
        step_run.update_columns(acted_at: clock, updated_at: clock)
        break if request.reload.status == "rejected"

        reject_here = rng.rand < REJECT_RATE && request.reload.status != "approved"
        if reject_here
          next_step = workflow_run.step_runs.where(status: "pending").order(:id).first
          runtime.act(next_step, action: "reject") if next_step
          next_step&.update_columns(acted_at: clock, updated_at: clock)
          break
        end
      end

      override(runtime, request, workflow_run, clock, rng) if !pending_tail && rng.rand < OVERRIDE_RATE
      finish_stamps(request, workflow_run, clock)
    end
    private_class_method :settle

    def self.override(runtime, request, workflow_run, clock, rng)
      step_run = workflow_run.step_runs.order(:id).last
      runtime.act(step_run, action: "override", reason: OVERRIDE_REASONS.sample(random: rng))
      step_run.update_columns(acted_at: clock + 1.hour, updated_at: clock + 1.hour)
      request.reload
    end
    private_class_method :override

    def self.stamp(request, workflow_run, time)
      request.update_columns(created_at: time, updated_at: time)
      workflow_run.update_columns(created_at: time, updated_at: time)
      workflow_run.step_runs.update_all(created_at: time, updated_at: time)
    end
    private_class_method :stamp

    def self.finish_stamps(request, workflow_run, time)
      workflow_run.step_runs.where(acted_at: nil, status: %w[done]).update_all(acted_at: time + 1.minute) # system steps
      request.reload.update_columns(updated_at: time)
      workflow_run.reload.update_columns(updated_at: time)
    end
    private_class_method :finish_stamps
  end
end
