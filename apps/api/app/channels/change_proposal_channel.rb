# Streams a company's change proposals as they gain their plain-English
# explanation (ProposalExplanationJob), so an open Proposals page fills it
# in without a refresh. No auth yet, same as the other channels.
class ChangeProposalChannel < ApplicationCable::Channel
  def subscribed
    stream_for Company.find(params[:company_id])
  end
end
