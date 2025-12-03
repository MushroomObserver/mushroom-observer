# frozen_string_literal: true

# Mass-mailing about new features.
class FeaturesMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(user, features)
    # Check preferences at delivery time (user may have opted out since queued)
    return if user.no_emails || !user.email_general_feature

    setup_user(user)
    @title = :email_subject_features.l
    @features = features
    mo_mail(@title, to: user)
  end
end
