require "rails_helper"

RSpec.describe Evals::Promotion do
  # SPEC.md section 12: "Promote" makes a challenger the active prompt, and
  # is refused if it regresses any case the current version passes —
  # unless a human confirms.
  let(:company) { create(:company) }
  let(:active) { create(:prompt_version, version: 1, active: true) }
  let(:challenger) { create(:prompt_version, version: 2) }
  let(:case_a) { create(:eval_case, suite: "policy_extraction", key: "a") }
  let(:case_b) { create(:eval_case, suite: "policy_extraction", key: "b") }

  def finish_run(version, results, at: Time.current)
    create(:eval_run, company: company, suite: "policy_extraction", prompt_version: version, status: "completed", finished_at: at).tap do |run|
      results.each { |eval_case, passed| create(:eval_result, eval_run: run, eval_case: eval_case, passed: passed) }
    end
  end

  describe ".regressions" do
    it "lists the cases the active version passes that the challenger fails" do
      finish_run(active, { case_a => true, case_b => true })
      finish_run(challenger, { case_a => true, case_b => false })

      expect(described_class.regressions(challenger: challenger, company: company)).to eq([ "b" ])
    end

    it "ignores cases the active version already fails, and counts a case the challenger never ran as a regression" do
      finish_run(active, { case_a => true, case_b => false })
      finish_run(challenger, {})

      expect(described_class.regressions(challenger: challenger, company: company)).to eq([ "a" ])
    end

    it "compares the latest completed run of each version" do
      finish_run(active, { case_a => true }, at: 2.days.ago)
      finish_run(active, { case_a => false }, at: 1.day.ago)
      finish_run(challenger, { case_a => false })

      expect(described_class.regressions(challenger: challenger, company: company)).to eq([])
    end

    it "is nil when the challenger hasn't been evaluated yet, so nobody promotes it blind" do
      finish_run(active, { case_a => true })

      expect(described_class.regressions(challenger: challenger, company: company)).to be_nil
    end
  end

  describe ".call" do
    it "promotes a challenger that regresses nothing" do
      finish_run(active, { case_a => true, case_b => false })
      finish_run(challenger, { case_a => true, case_b => true })

      described_class.call(prompt_version: challenger, company: company)

      expect(challenger.reload).to be_active
      expect(active.reload).not_to be_active
    end

    it "refuses a challenger that regresses a case, naming it" do
      finish_run(active, { case_a => true })
      finish_run(challenger, { case_a => false })

      expect { described_class.call(prompt_version: challenger, company: company) }
        .to raise_error(described_class::Blocked) { |error| expect(error.regressions).to eq([ "a" ]) }
      expect(active.reload).to be_active
    end

    it "promotes anyway when a human confirms" do
      finish_run(active, { case_a => true })
      finish_run(challenger, { case_a => false })

      described_class.call(prompt_version: challenger, company: company, confirm: true)

      expect(challenger.reload).to be_active
    end

    it "refuses an unevaluated challenger unless confirmed" do
      finish_run(active, { case_a => true })

      expect { described_class.call(prompt_version: challenger, company: company) }.to raise_error(described_class::Blocked, /hasn't been evaluated/)
    end

    it "promotes freely when nothing is active yet" do
      described_class.call(prompt_version: challenger, company: company)

      expect(challenger.reload).to be_active
    end
  end
end
