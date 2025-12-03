# frozen_string_literal: true

module Admin
  module Emails
    class FeaturesController < AdminController
      def new
        @users = ::User.where(email_general_feature: true, no_emails: false).
                 where.not(verified: nil)
      end

      def create
        @users = ::User.where(email_general_feature: true, no_emails: false).
                 where.not(verified: nil)
        content = params[:feature_email][:content]

        if content.blank?
          flash_error(:runtime_missing.t(field: :message.l))
          render(:new) and return
        end

        # Migrated from QueuedEmail::Features to ActionMailer + ActiveJob.
        # See .claude/deliver_later_migration_plan.md for details.
        @users.each do |user|
          FeaturesMailer.build(user, content).deliver_later
        end
        flash_notice(:send_feature_email_success.t)
        redirect_to(users_path(by: "name"))
      end
    end
  end
end
