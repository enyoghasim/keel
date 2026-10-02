module Assemble
  # Edit distance for fuzzy manager-name matching (SPEC.md section 6, stage
  # 2) — no gem dependency for something this small and this central.
  class Levenshtein
    def self.distance(a, b)
      return b.length if a.empty?
      return a.length if b.empty?

      costs = (0..b.length).to_a

      a.each_char.with_index do |ca, i|
        costs[0] = i + 1
        diagonal = i

        b.each_char.with_index do |cb, j|
          previous_cost = costs[j + 1]
          costs[j + 1] = [ costs[j + 1] + 1, costs[j] + 1, diagonal + (ca == cb ? 0 : 1) ].min
          diagonal = previous_cost
        end
      end

      costs[b.length]
    end
  end
end
