FactoryBot.define do
  factory :eval_case do
    suite { "insights" }
    sequence(:key) { |n| "case_#{n}" }
    input { { "question" => "Leave days by department last quarter", "today" => "2026-10-02" } }
    expected do
      { "query" => { "metric" => "leave_days", "group_by" => "department", "chart" => "bar",
                     "time_range" => { "from" => "2026-07-01", "to" => "2026-09-30" } } }
    end
  end
end
