# frozen_string_literal: true

# Shared Observation-specific link-URL builders, confirmed identical
# shape across ConsensusChangeMailer, NameProposalMailer, and
# ObservationChangeMailer's `observation_links`. NOT for CommentMailer
# — its target is polymorphic (any commentable model, not just
# Observation), so its show_object_url uses `@target.show_controller`
# and a dynamic type rather than Observation's bare `/#{id}` route.
#
# Include into a mailer's `Build` class (shared by both Html/Text,
# unlike CommonSections — these are plain data methods, no html?
# branching). Requires `@observation` and `@receiver` ivars.
# `stop_sending_link` additionally requires the including class to
# define `stop_sending_type` (e.g. "observations_consensus").
module Views::Mailers::ObservationLinks
  private

  def show_object_url
    "#{MO.http_domain}/#{@observation.id}"
  end

  def post_comment_url
    "#{MO.http_domain}/comments/new?target=#{@observation.id}" \
      "&type=Observation"
  end

  def not_interested_url
    "#{MO.http_domain}/interests/set_interest?id=#{@observation.id}" \
      "&type=Observation&user=#{@receiver.id}&state=-1"
  end

  def stop_sending_link
    return [] if @receiver.watching?(@observation)

    [[:email_links_stop_sending.t,
      "#{MO.http_domain}/account/no_email/#{@receiver.id}" \
      "?type=#{stop_sending_type}"]]
  end
end
