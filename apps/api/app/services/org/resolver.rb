module Org
  class Resolver
    Result = Data.define(:person_ids, :error)

    def initialize(snapshot) = @g = snapshot

    def resolve(reference, requester_id:)
      ids = case reference
      when "requester"                     then [ requester_id ]
      when "manager_of(requester)"          then [ @g.manager_of(requester_id) ]
      when "skip_manager_of(requester)"     then [ @g.manager_of(@g.manager_of(requester_id)) ]
      when "head_of(requester.department)"  then [ @g.head_of_dept(@g.people.dig(requester_id, "department_id")) ]
      when /\Arole:(\w+)\z/                 then @g.holders_of($1)
      when /\Aperson:(\d+)\z/               then [ $1.to_i ]
      else return Result.new([], "unknown reference #{reference}")
      end.compact

      return Result.new([], "#{reference} resolved to nobody") if ids.empty?
      return Result.new(ids, "self-approval") if ids == [ requester_id ] && reference != "requester"

      Result.new(ids, nil)
    end
  end
end
