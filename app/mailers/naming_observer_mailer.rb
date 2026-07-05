# frozen_string_literal: true

# Tell observer someone is interested in their obs.
class NamingObserverMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(receiver:, naming:, name_tracker:)
    return unless name_tracker.approved

    sender = name_tracker.user
    setup_user(receiver)
    subject = :email_subject_naming_for_observer.l
    debug_log(:naming_for_observer, sender, @user,
              naming:, name_tracker:)
    mo_mail(subject, to: receiver, reply_to: sender,
                     view_namespace: Views::Mailers::NamingObserverMailer,
                     view_params: { subject:, receiver:, naming:,
                                    name_tracker: })
  end
end
