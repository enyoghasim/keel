module Rules
  class Context
    def self.build(request, snapshot)
      person = snapshot.people.fetch(request.requester_id)
      department = snapshot.departments[person["department_id"]]
      payload = request.payload

      {
        "requester.department" => department && department["name"],
        "requester.location" => person["location"],
        "requester.tenure_months" => tenure_months(person["start_date"]),
        "payload.amount_eur" => payload["amount_eur"],
        "payload.category" => payload["category"],
        "payload.days" => payload["days"],
        "payload.notice_days" => payload["notice_days"]
      }
    end

    def self.tenure_months(start_date)
      return nil if start_date.nil?

      start_date = Date.parse(start_date) if start_date.is_a?(String)
      (Date.current.year * 12 + Date.current.month) - (start_date.year * 12 + start_date.month)
    end
  end
end
