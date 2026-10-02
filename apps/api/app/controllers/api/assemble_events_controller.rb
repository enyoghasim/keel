module Api
  # The events AssembleJob has broadcast so far, for a page that subscribed
  # after the job started. Public like Companies#show: Assemble runs before
  # anyone exists to sign in.
  class AssembleEventsController < ApplicationController
    def index
      render_success(data: Company.find(params[:company_id]).assemble_events)
    end
  end
end
