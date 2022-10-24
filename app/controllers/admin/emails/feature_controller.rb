# frozen_string_literal: true

module Admin::Emails
  class FeatureController < ApplicationController
    include Admin::RestrictAccessToAdminMode

    before_action :login_required

    def new
      @users = User.where("email_general_feature=1 && verified is not null")
    end

    def create
      @users = User.where("email_general_feature=1 && verified is not null")
      @users.each do |user|
        QueuedEmail::Feature.create_email(user,
                                          params[:feature_email][:content])
      end
      flash_notice(:send_feature_email_success.t)
      redirect_to(users_path(by: "name"))
    end
  end
end
