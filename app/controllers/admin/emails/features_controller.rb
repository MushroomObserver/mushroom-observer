# frozen_string_literal: true

module Admin
  module Emails
    class FeaturesController < AdminController
      def new
        @users = ::User.where(email_general_feature: true, no_emails: false).
                 where.not(verified: nil)
      end

      def create
        @users = feature_email_recipients
        return unless content_present?

        # Migrated from QueuedEmail::Features to ActionMailer + ActiveJob.
        # See .claude/deliver_later_migration_plan.md for details.
        @users.each { |user| FeaturesMailer.build(user, content).deliver_later }
        flash_notice(:send_feature_email_success.t)
        redirect_to(users_path(by: "name"))
      end

      private

      def feature_email_recipients
        ::User.where(email_general_feature: true, no_emails: false).
          where.not(verified: nil)
      end

      def content
        params[:feature_email][:content]
      end

      def content_present?
        return true if content.present?

        flash_error(:runtime_missing.t(field: :message.l))
        render(:new)
        false
      end
    end
  end
end
