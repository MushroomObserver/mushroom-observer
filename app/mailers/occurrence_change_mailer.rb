# frozen_string_literal: true

# Notify observation owner when their observation is added to or
# removed from an occurrence.
class OccurrenceChangeMailer < ApplicationMailer
  def build(sender:, receiver:, observation:, action:)
    setup_user(receiver)
    # Plain text_name, not the Textile-marked-up format_name used in
    # the body's intro sentence — a mail Subject header can't render
    # markup, so the raw "**__Fungi__**" asterisks would show up
    # literally in the recipient's inbox otherwise.
    name = observation.unique_text_name(receiver)
    subject = :"email_subject_occurrence_#{action}".l(name:)
    debug_log(:occurrence_change, sender, receiver, observation:)
    mo_mail(subject, to: receiver,
                     view_params: { subject:, receiver:, sender:, observation:,
                                    action: action.to_s })
  end
end
