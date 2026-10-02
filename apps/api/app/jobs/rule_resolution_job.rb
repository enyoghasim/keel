# Applies one answer to a rule's open question (SPEC.md section 7):
# Assemble::AmbiguityResolver rewrites the rule (the only LLM step) and saves
# it as a new version. Runs as a job because the resolver waits on a model;
# the outcome is recorded on the RuleResolution and broadcast on
# RuleResolutionChannel.
class RuleResolutionJob < ApplicationJob
  INVALID = "Keel couldn't turn that answer into a valid rule. The rule is unchanged; try again or pick another option.".freeze
  UNEXPECTED = "Something went wrong updating that rule. Please try again.".freeze

  def perform(rule_resolution_id)
    resolution = RuleResolution.find(rule_resolution_id)
    return unless resolution.status == "pending"

    resolve(resolution)
    RuleResolutionChannel.broadcast_to(resolution, resolution.as_payload)
  end

  private

  def resolve(resolution)
    result = Assemble::AmbiguityResolver.call(rule: resolution.rule, ambiguity_index: resolution.ambiguity_index, answer: resolution.answer)
    resolution.update!(status: "resolved", new_rule: result.after, model: RubyLLM.config.default_model)
  rescue Assemble::AmbiguityResolver::InvalidRewrite, Llm::StructuredAsk::ValidationError => e
    Rails.logger.warn("[RuleResolutionJob] #{e.class}: #{e.message}")
    resolution.update!(status: "failed", error_message: INVALID)
  rescue StandardError => e
    Rails.logger.error("[RuleResolutionJob] #{e.class}: #{e.message}")
    resolution.update!(status: "failed", error_message: UNEXPECTED)
  end
end
