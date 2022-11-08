# frozen_string_literal: true

# Tell observer someone is interested in their obs.
class NamingObserverMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(observer, naming, notification)
    sender = notification.user
    setup_user(observer)
    @title = :email_subject_naming_for_observer.l
    @naming = naming
    @notification = notification
    debug_log(:naming_for_observer, sender, @user,
              naming: naming, notification: notification)
    mo_mail(@title, to: observer, reply_to: sender)
  end
end
