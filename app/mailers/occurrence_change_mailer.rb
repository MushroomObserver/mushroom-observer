# frozen_string_literal: true

# Notify observation owner when their observation is added to or
# removed from an occurrence.
class OccurrenceChangeMailer < ApplicationMailer
  def build(sender:, receiver:, observation:, action:)
    setup_user(receiver)
    name = observation.user_unique_format_name(receiver)
    @title = :"email_subject_occurrence_#{action}".l(name: name)
    @sender = sender
    @observation = observation
    @action = action
    debug_log(:occurrence_change, sender, receiver, observation:)
    mo_mail(@title, to: receiver)
  end
end
