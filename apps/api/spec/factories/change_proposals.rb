FactoryBot.define do
  factory :change_proposal do
    company
    kind { "org" }
    title { "Move Sales under Ada Nwosu" }
    diff { [ { "op" => "change_manager", "person_id" => 1, "to" => 2 } ] }
    impact { { "rerouted" => [], "broken" => [], "self_approval" => [], "approval_load_changes" => [], "rerouted_in_flight" => [] } }
    proposed_by { "user" }
  end
end
