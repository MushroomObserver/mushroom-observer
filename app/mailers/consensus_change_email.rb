# frozen_string_literal: true

# Notify user of name change of their obs.
class ConsensusChangeEmail < AccountMailer
  def build(email)
    setup_user(email.to_user)
    @observation = email.observation
    @old_name = email.old_name
    @new_name = email.new_name
    @time = email.queued
    @title = consensus_change_title(@observation, @old_name, @new_name)
    @sender = email.user
    debug_log(:consensus_change, @sender, @user, observation: @observation)
    mo_mail(@title, to: @user)
  end

  private

  def consensus_change_title(observation, old_name, new_name)
    :email_subject_consensus_change.l(
      id: observation.id,
      old: (old_name ? old_name.real_search_name : "none"),
      new: (new_name ? new_name.real_search_name : "none")
    )
  end
end
