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
        return unless message_present?

        # Migrated from QueuedEmail::Features to ActionMailer + ActiveJob.
        # See .claude/deliver_later_migration_plan.md for details.
        message = params[:feature_email][:content]
        @users.each do |receiver|
          FeaturesMailer.build(receiver:, message:).deliver_later
        end
        flash_notice(:send_feature_email_success.t)
        redirect_to(users_path(by: "name"))
      end

      private

      def feature_email_recipients
        ::User.where(email_general_feature: true, no_emails: false).
          where.not(verified: nil)
      end

      def message_present?
        return true if params[:feature_email][:content].present?

        flash_error(:runtime_missing.t(field: :message.l))
        render(:new)
        false
      end
    end
  end
end
