# frozen_string_literal: true

# Notify user someone has observed a name they are interested in.
class NamingTrackerMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(receiver:, naming:)
    setup_user(receiver)
    search_name = naming.name.real_search_name(receiver)
    name = "#{naming.observation_id}: #{search_name}"
    subject = :email_subject_naming_for_tracker.l(name:)
    observation = naming.observation
    debug_log(:naming_for_tracker, nil, receiver, naming:, observation:)
    mo_mail(subject, to: receiver,
                     view_params: { subject:, receiver:, observation:,
                                    naming: })
  end
end
