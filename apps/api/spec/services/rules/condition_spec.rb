require "rails_helper"

RSpec.describe Rules::Condition do
  describe ".match?" do
    it "matches an eq leaf" do
      node = { "field" => "payload.category", "op" => "eq", "value" => "conference" }

      expect(described_class.match?(node, { "payload.category" => "conference" })).to be true
      expect(described_class.match?(node, { "payload.category" => "travel" })).to be false
    end

    it "matches a neq leaf" do
      node = { "field" => "payload.category", "op" => "neq", "value" => "conference" }

      expect(described_class.match?(node, { "payload.category" => "travel" })).to be true
      expect(described_class.match?(node, { "payload.category" => "conference" })).to be false
    end

    it "matches gt/gte/lt/lte leaves" do
      ctx = { "payload.amount_eur" => 1000 }

      expect(described_class.match?({ "field" => "payload.amount_eur", "op" => "gt", "value" => 999 }, ctx)).to be true
      expect(described_class.match?({ "field" => "payload.amount_eur", "op" => "gt", "value" => 1000 }, ctx)).to be false
      expect(described_class.match?({ "field" => "payload.amount_eur", "op" => "gte", "value" => 1000 }, ctx)).to be true
      expect(described_class.match?({ "field" => "payload.amount_eur", "op" => "lt", "value" => 1001 }, ctx)).to be true
      expect(described_class.match?({ "field" => "payload.amount_eur", "op" => "lte", "value" => 1000 }, ctx)).to be true
      expect(described_class.match?({ "field" => "payload.amount_eur", "op" => "lte", "value" => 999 }, ctx)).to be false
    end

    it "matches in/not_in leaves" do
      ctx = { "requester.department" => "Engineering" }
      in_node = { "field" => "requester.department", "op" => "in", "value" => %w[Engineering Sales] }
      not_in_node = { "field" => "requester.department", "op" => "not_in", "value" => %w[Finance IT] }

      expect(described_class.match?(in_node, ctx)).to be true
      expect(described_class.match?(not_in_node, ctx)).to be true
      expect(described_class.match?({ "field" => "requester.department", "op" => "in", "value" => %w[Finance] }, ctx)).to be false
    end

    it "matches a between leaf inclusively" do
      node = { "field" => "payload.amount_eur", "op" => "between", "value" => [ 500, 1000 ] }

      expect(described_class.match?(node, { "payload.amount_eur" => 500 })).to be true
      expect(described_class.match?(node, { "payload.amount_eur" => 1000 })).to be true
      expect(described_class.match?(node, { "payload.amount_eur" => 1001 })).to be false
      expect(described_class.match?(node, { "payload.amount_eur" => 499 })).to be false
    end

    it "requires every child of an 'all' node to match" do
      node = {
        "all" => [
          { "field" => "requester.department", "op" => "eq", "value" => "Engineering" },
          { "field" => "payload.category", "op" => "eq", "value" => "conference" }
        ]
      }
      ctx = { "requester.department" => "Engineering", "payload.category" => "conference" }

      expect(described_class.match?(node, ctx)).to be true
      expect(described_class.match?(node, ctx.merge("payload.category" => "travel"))).to be false
    end

    it "requires at least one child of an 'any' node to match" do
      node = {
        "any" => [
          { "field" => "payload.category", "op" => "eq", "value" => "conference" },
          { "field" => "payload.category", "op" => "eq", "value" => "travel" }
        ]
      }

      expect(described_class.match?(node, { "payload.category" => "travel" })).to be true
      expect(described_class.match?(node, { "payload.category" => "equipment" })).to be false
    end

    it "supports nested all/any combinations" do
      node = {
        "all" => [
          { "field" => "requester.department", "op" => "eq", "value" => "Engineering" },
          {
            "any" => [
              { "field" => "payload.category", "op" => "eq", "value" => "conference" },
              { "field" => "payload.category", "op" => "eq", "value" => "training" }
            ]
          }
        ]
      }

      ctx = { "requester.department" => "Engineering", "payload.category" => "training" }
      expect(described_class.match?(node, ctx)).to be true

      ctx = { "requester.department" => "Sales", "payload.category" => "training" }
      expect(described_class.match?(node, ctx)).to be false
    end

    it "raises on an unknown operator" do
      node = { "field" => "payload.amount_eur", "op" => "near", "value" => 100 }

      expect { described_class.match?(node, { "payload.amount_eur" => 100 }) }
        .to raise_error(ArgumentError, /unknown operator/)
    end
  end
end
