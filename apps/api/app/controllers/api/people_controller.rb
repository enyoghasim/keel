module Api
  class PeopleController < ApplicationController
    include CompanyScoped

    FIELDS = %i[id name email title department_id manager_id location start_date roles].freeze

    def index
      render_success(data: @company.people.map { serialize(_1) })
    end

    def show
      render_success(data: serialize(@company.people.find(params[:id])))
    end

    private

    def serialize(person) = person.as_json(only: FIELDS)
  end
end
