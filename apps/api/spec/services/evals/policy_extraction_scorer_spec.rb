require "rails_helper"

RSpec.describe Evals::PolicyExtractionScorer do
  # SPEC.md section 12's policy_extraction scoring: behaviour on probe
  # requests, verbatim quote verification, and ambiguity recall.
  let(:passage) { "Engineers attending conferences are automatically approved up to €1,000." }
  let(:conditions) do
    ->(op) { { "all" => [
      { "field" => "requester.department", "op" => "eq", "value" => "Engineering" },
      { "field" => "payload.amount_eur", "op" => op, "value" => 1000 }
    ] } }
  end
  let(:expected) do
    { "rules" => [ { "key" => "conf", "priority" => 10, "conditions" => conditions.call("lte"), "actions" => { "decision" => "auto_approve" } } ],
      "ambiguities" => [ "attending conferences" ] }
  end

  def actual_rule(op: "lte", quote: passage, ambiguities: [ { "phrase" => "attending conferences", "question" => "?", "options" => [ "a", "b" ] } ])
    { "key" => "conference_limit", "priority" => 10, "conditions" => conditions.call(op), "actions" => { "decision" => "auto_approve" },
      "source_quote" => quote, "ambiguities" => ambiguities }
  end

  def score(*rules) = described_class.call(expected: expected, actual_rules: rules, passage: passage)

  it "passes a compile that behaves like the expected rules, quotes the passage and flags the ambiguity" do
    result = score(actual_rule)

    expect(result).to have_attributes(passed: true, score: 1.0, diff: [])
    expect(result.metrics).to eq("behaviour" => 1.0, "quotes_verified" => 1.0, "ambiguity_recall" => 1.0, "probes" => 3)
  end

  it "fails a lt-for-lte mistake and names the disagreeing probe, scoring the share of probes it got right" do
    result = score(actual_rule(op: "lt"))

    expect(result.passed).to be(false)
    expect(result.score).to be_within(0.001).of(2 / 3.0)
    expect(result.diff).to contain_exactly(
      a_hash_including("field" => "behaviour", "probe" => { "requester.department" => "Engineering", "payload.amount_eur" => 1000 },
        "expected" => "auto_approve", "actual" => "require_approval (manager_of(requester))")
    )
  end

  it "fails a rule whose source_quote isn't in the passage — a hallucinated quote" do
    result = score(actual_rule(quote: "Everyone gets a free laptop."))

    expect(result.passed).to be(false)
    expect(result.metrics["quotes_verified"]).to eq(0.0)
    expect(result.diff).to include(a_hash_including("field" => "source_quote", "actual" => "Everyone gets a free laptop."))
  end

  it "fails when an ambiguity a good extraction should flag is missed, without hurting the behaviour score" do
    result = score(actual_rule(ambiguities: []))

    expect(result.passed).to be(false)
    expect(result.metrics).to include("behaviour" => 1.0, "ambiguity_recall" => 0.0)
    expect(result.diff).to include(a_hash_including("field" => "ambiguity", "expected" => "attending conferences"))
  end

  it "matches ambiguity phrases loosely, ignoring case and surrounding words" do
    result = score(actual_rule(ambiguities: [ { "phrase" => "Attending Conferences abroad", "question" => "?", "options" => [ "a", "b" ] } ]))

    expect(result.metrics["ambiguity_recall"]).to eq(1.0)
  end

  it "scores a compile that produced no rules as a behavioural miss" do
    result = score

    expect(result.passed).to be(false)
    expect(result.metrics["behaviour"]).to be < 1.0
  end

  it "doesn't require ambiguities when the case expects none" do
    result = described_class.call(expected: expected.except("ambiguities"), actual_rules: [ actual_rule(ambiguities: []) ], passage: passage)

    expect(result.passed).to be(true)
    expect(result.metrics["ambiguity_recall"]).to be_nil
  end
end
