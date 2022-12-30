# frozen_string_literal: true

# Tell observer someone is interested in their obs.
class NamingObserverMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(observer, naming, name_tracker)
    return unless name_tracker.approved

    sender = name_tracker.user
    setup_user(observer)
    @title = :email_subject_naming_for_observer.l
    @naming = naming
    @name_tracker = name_tracker
    debug_log(:naming_for_observer, sender, @user,
              naming: naming, name_tracker: name_tracker)
    mo_mail(@title, to: observer, reply_to: sender)
  end
end
