# frozen_string_literal: true

# Notify user of name change of their obs.
class ConsensusChangeMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(sender:, receiver:, observation:, old_name:, new_name:)
    setup_user(receiver)
    @observation = observation
    @old_name = old_name
    @new_name = new_name
    @time = Time.zone.now
    @title = consensus_change_title(@observation, @old_name, @new_name)
    @sender = sender
    debug_log(:consensus_change, @sender, @user, observation: @observation)
    mo_mail(@title, to: @user)
  end

  private

  def consensus_change_title(observation, old_name, new_name)
    :email_subject_consensus_change.l(
      id: observation.id,
      old: (old_name ? old_name.user_real_search_name(@user) : "none"),
      new: (new_name ? new_name.user_real_search_name(@user) : "none")
    )
  end
end
