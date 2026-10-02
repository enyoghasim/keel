module Api
  class DepartmentsController < ApplicationController
    include CompanyScoped

    FIELDS = %i[id name head_id].freeze

    def index
      render_success(data: @company.departments.map { serialize(_1) })
    end

    def show
      render_success(data: serialize(@company.departments.find(params[:id])))
    end

    private

    def serialize(department) = department.as_json(only: FIELDS)
  end
end
