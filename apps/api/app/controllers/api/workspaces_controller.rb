module Api
  # Tells a browser which company this deployment serves (the first one
  # created — a deployment is one company, and Api::CompaniesController
  # refuses a second). Public on purpose: the sign-in page needs it before
  # anyone is signed in, and it exposes only the company's name and whether
  # the demo can be reset.
  class WorkspacesController < ApplicationController
    def show
      company = Company.order(:id).first
      render_success(data: {
        company: company && { id: company.id, name: company.name, assembling: company.assembling? },
        demo_reset: Demo::Reset.enabled?
      })
    end
  end
end
