module CompanyScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_company
  end

  private

  def set_company
    @company = Company.find(params[:company_id])
  end
end
