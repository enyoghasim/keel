module Org
  class GraphSnapshot
    attr_reader :people, :departments

    def self.load(company)
      new(
        people: company.people.index_by(&:id).transform_values(&:attributes),
        departments: company.departments.index_by(&:id).transform_values(&:attributes)
      )
    end

    def initialize(people:, departments:)
      @people = people
      @departments = departments
    end

    # Returns a new snapshot with the diff applied; never mutates self.
    def with_change(diff)
      copy = GraphSnapshot.new(people: people.deep_dup, departments: departments.deep_dup)
      diff.each { |op| copy.apply!(op) }
      copy
    end

    def manager_of(id) = people.dig(id, "manager_id")
    def holders_of(role) = people.values.select { _1["roles"].include?(role) }.map { _1["id"] }
    def head_of_dept(dept_id) = departments.dig(dept_id, "head_id")

    protected

    def apply!(op)
      case op["op"]
      when "change_manager"
        people.dig(op["person_id"])["manager_id"] = op["to"]
      when "set_department_head"
        departments.dig(op["department_id"])["head_id"] = op["to"]
      when "assign_role"
        people.dig(op["person_id"])["roles"] << op["role"]
      else
        raise ArgumentError, "unknown diff operation #{op["op"]}"
      end
    end
  end
end
