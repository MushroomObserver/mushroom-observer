# frozen_string_literal: true

# Mass-mailing about new features.
class FeaturesMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(user, features)
    setup_user(user)
    @title = :email_subject_features.l
    @features = features
    mo_mail(@title, to: user)
  end
end
