require "rails_helper"

RSpec.describe Agent::ProposalExplainer do
  # SPEC.md section 10: the proposal page's paragraph is written by the LLM
  # from the computed impact only. #facts is the deterministic half — the
  # only thing the model is shown — and #call refuses a paragraph that
  # states a number the facts don't contain, so it cannot invent an effect.
  let(:company) { create(:company) }
  let(:tunde) { create(:person, company: company, name: "Tunde Bakare") }
  let(:ada) { create(:person, company: company, name: "Ada Nwosu") }
  let(:ngozi) { create(:person, company: company, name: "Ngozi Okafor") }
  let(:chat) { instance_double(RubyLLM::Chat) }

  def decision(approvers, errors: []) = { "outcome" => "require_approval", "approvers" => approvers, "errors" => errors, "rule_keys" => [], "explanation" => nil }

  def message_with(text) = instance_double(RubyLLM::Message, content: { "explanation" => text })

  describe ".facts" do
    it "describes an org proposal's impact with names, not ids" do
      proposal = create(:change_proposal, company: company, title: "Move Sales under Ada", impact: {
        "rerouted" => [ { "person_id" => ngozi.id, "before" => decision([ tunde.id ]), "after" => decision([ ada.id ]) } ],
        "broken" => [ { "person_id" => ngozi.id, "before" => decision([ tunde.id ]), "after" => decision([], errors: [ "role:finance_lead resolved to nobody" ]) } ],
        "self_approval" => [],
        "approval_load_changes" => [ { "approver_id" => ada.id, "before" => 6, "after" => 21 } ],
        "rerouted_in_flight" => [ { "step_run_id" => 1 } ]
      })

      expect(described_class.facts(proposal)).to eq(
        "kind" => "org", "title" => "Move Sales under Ada",
        "rerouted_count" => 1, "rerouted_examples" => [ { "person" => "Ngozi Okafor", "before" => [ "Tunde Bakare" ], "after" => [ "Ada Nwosu" ] } ],
        "broken_count" => 1, "broken_examples" => [ { "person" => "Ngozi Okafor", "problems" => [ "role:finance_lead resolved to nobody" ] } ],
        "self_approval_count" => 0,
        "approval_load_changes" => [ { "approver" => "Ada Nwosu", "before" => 6, "after" => 21 } ],
        "open_requests_rerouted" => 1
      )
    end

    it "describes a rule proposal's backtest" do
      proposal = create(:change_proposal, company: company, kind: "rule", title: "Expense: raise the limit", impact: {
        "backtest" => { "total" => 412, "flipped_count" => 23, "summary" => "This would have changed 23 of 412 past decisions.",
                        "new_conflicts" => [ { "rules" => %w[a b], "warning" => "a and b now overlap" } ], "flipped" => [] }
      })

      expect(described_class.facts(proposal)).to eq(
        "kind" => "rule", "title" => "Expense: raise the limit", "past_requests_replayed" => 412, "decisions_flipped" => 23,
        "summary" => "This would have changed 23 of 412 past decisions.", "new_conflicts" => [ "a and b now overlap" ]
      )
    end

    it "describes a workflow proposal's step diff and reach" do
      proposal = create(:change_proposal, company: company, kind: "workflow", title: "Leave: add IT", impact: {
        "steps" => { "added" => [ "it_setup" ], "removed" => [], "changed" => [], "moved" => [] }, "affected_count" => 77,
        "broken" => [ { "step_key" => "it_setup", "reference" => "role:it_admin", "person_count" => 77 } ], "in_flight" => 0
      })

      expect(described_class.facts(proposal)).to eq(
        "kind" => "workflow", "title" => "Leave: add IT", "steps_added" => [ "it_setup" ], "steps_removed" => [], "steps_changed" => [], "steps_moved" => [],
        "people_affected" => 77, "broken_steps" => [ { "step" => "it_setup", "reference" => "role:it_admin", "people" => 77 } ], "open_requests_on_removed_steps" => 0
      )
    end
  end

  describe ".call" do
    let(:proposal) do
      create(:change_proposal, company: company, title: "Move Sales under Ada", impact: {
        "rerouted" => [ { "person_id" => ngozi.id, "before" => decision([ tunde.id ]), "after" => decision([ ada.id ]) } ],
        "broken" => [], "self_approval" => [], "approval_load_changes" => [ { "approver_id" => ada.id, "before" => 6, "after" => 21 } ], "rerouted_in_flight" => []
      })
    end

    before do
      allow(RubyLLM).to receive(:chat).and_return(chat)
      allow(chat).to receive(:with_schema).and_return(chat)
    end

    it "returns the model's paragraph, having shown it the facts and nothing else about the proposal" do
      allow(chat).to receive(:ask).and_return(message_with("This gives Ada more approval work: she goes from 6 to 21 approvals, and 1 person's requests are rerouted."))

      text = described_class.call(proposal)

      expect(text).to eq("This gives Ada more approval work: she goes from 6 to 21 approvals, and 1 person's requests are rerouted.")
      expect(chat).to have_received(:ask).with(a_string_including("Ada Nwosu", "21", "Ngozi Okafor").and(satisfy { !_1.include?(ada.id.to_s * 3) }))
    end

    it "refuses a paragraph that states a number the impact doesn't contain" do
      allow(chat).to receive(:ask).and_return(message_with("Ada's load goes from 6 to 40 approvals."))

      expect { described_class.call(proposal) }.to raise_error(described_class::Unfaithful, /40/)
    end
  end
end
