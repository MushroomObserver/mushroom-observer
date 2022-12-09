# frozen_string_literal: true

module Admin::Emails
  class FeatureController < AdminController
    def new
      @users = User.where(email_general_feature: true, no_emails: false).
               where.not(verified: nil)
    end

    def create
      @users = User.where(email_general_feature: true, no_emails: false).
               where.not(verified: nil)
      @users.each do |user|
        QueuedEmail::Feature.create_email(user,
                                          params[:feature_email][:content])
      end
      flash_notice(:send_feature_email_success.t)
      redirect_to(users_path(by: "name"))
    end
  end
end
