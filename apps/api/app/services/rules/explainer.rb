module Rules
  class Explainer
    DECISION_PHRASES = {
      "auto_approve" => "Auto approved",
      "reject" => "Rejected",
      "require_approval" => "Sent for approval",
      "blocked" => "Blocked"
    }.freeze

    # Deliberately minimal: a handbook-quote citation ("Handbook p.4") needs
    # a persisted rule with a source_chunk, which doesn't exist yet (that's
    # the policy-extraction work). This gives a true, if plainer, sentence
    # in the meantime rather than faking a citation.
    def self.call(winner, _ctx)
      return "No rule matched; the policy's default action applied." if winner.nil?

      decision = winner.actions["decision"]
      phrase = DECISION_PHRASES.fetch(decision, decision.to_s.tr("_", " ").capitalize)
      "#{phrase} — matched rule '#{winner.key}'."
    end
  end
end
