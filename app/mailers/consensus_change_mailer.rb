# frozen_string_literal: true

# Notify user of name change of their obs.
class ConsensusChangeMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(sender:, receiver:, observation:, old_name:, new_name:)
    setup_user(receiver)
    time = Time.zone.now
    subject = consensus_change_title(receiver, observation, old_name, new_name)
    debug_log(:consensus_change, sender, receiver, observation:)
    mo_mail(subject, to: receiver,
                     view_params: { subject:, receiver:, sender:, observation:,
                                    old_name:, new_name:, time: })
  end

  private

  def consensus_change_title(receiver, observation, old_name, new_name)
    :email_subject_consensus_change.l(
      id: observation.id,
      old: (old_name ? old_name.user_real_search_name(receiver) : "none"),
      new: (new_name ? new_name.user_real_search_name(receiver) : "none")
    )
  end
end
