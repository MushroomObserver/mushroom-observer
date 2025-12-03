# frozen_string_literal: true

# Mass-mailing about new features.
class FeaturesMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(receiver:, message:)
    # Check preferences at delivery time (user may have opted out since queued)
    return if receiver.no_emails || !receiver.email_general_feature

    setup_user(receiver)
    @title = :email_subject_features.l
    @features = message
    mo_mail(@title, to: receiver)
  end
end
