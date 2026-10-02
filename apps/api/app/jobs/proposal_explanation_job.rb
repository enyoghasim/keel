# Writes the plain-English paragraph on a change proposal (SPEC.md section
# 10) with Agent::ProposalExplainer and broadcasts the proposal to its
# company. The paragraph is a reading aid, so when the model fails or states
# something the impact doesn't contain the proposal simply has none.
class ProposalExplanationJob < ApplicationJob
  def perform(change_proposal_id)
    proposal = ChangeProposal.find(change_proposal_id)
    return if proposal.explanation.present?

    proposal.update!(explanation: Agent::ProposalExplainer.call(proposal))
    ChangeProposalChannel.broadcast_to(proposal.company, proposal.as_json(only: ChangeProposal::BROADCAST_FIELDS))
  rescue Agent::ProposalExplainer::Unfaithful, Llm::StructuredAsk::ValidationError => e
    Rails.logger.warn("[ProposalExplanationJob] proposal #{change_proposal_id}: #{e.class}: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("[ProposalExplanationJob] proposal #{change_proposal_id}: #{e.class}: #{e.message}")
  end
end
