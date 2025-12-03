# frozen_string_literal: true

module Admin
  module Emails
    # NOTE: Does not inherit from AdminController
    class WebmasterQuestionsController < ApplicationController
      def new
        @email = params.dig(:user, :email)
        @content = params.dig(:question, :content)
        @email = @user.email if @user

        respond_to do |format|
          format.html
          format.turbo_stream do
            render(
              partial: "shared/modal_form",
              locals: {
                title: :ask_webmaster_title.l,
                identifier: "webmaster_question_email",
                user: @user, form: "admin/email/webmaster_questions/form"
              }
            ) and return
          end
        end
      end

      def create
        @email = params.dig(:webmaster_question, :user, :email)
        @content = params.dig(:webmaster_question, :question, :content)
        @email_error = false
        create_webmaster_question
      end

      private

      def create_webmaster_question
        if invalid_email?
          handle_invalid_email
        elsif @content.blank?
          handle_missing_content
        elsif non_user_potential_spam?
          handle_spam
        else
          send_email_and_redirect
        end
      end

      def invalid_email?
        @email.blank? || @email.index("@").nil?
      end

      def handle_invalid_email
        flash_error(:runtime_ask_webmaster_need_address.t)
        @email_error = true
        render(:new)
      end

      def handle_missing_content
        flash_error(:runtime_ask_webmaster_need_content.t)
        render(:new)
      end

      def handle_spam
        flash_error(:runtime_ask_webmaster_antispam.t)
        render(:new)
      end

      def send_email_and_redirect
        # Migrated from QueuedEmail::Webmaster to ActionMailer + ActiveJob.
        content = WebmasterMailer.prepend_user(@user, @content)
        WebmasterMailer.build(sender_email: @email, content: content).
          deliver_later
        flash_notice(:runtime_ask_webmaster_success.t)
        redirect_to("/")
      end

      def non_user_potential_spam?
        !@user && (
          /https?:/.match?(@content) ||
          %r{<[/a-zA-Z]+>}.match?(@content) ||
          @content.exclude?(" ")
        )
      end
    end
  end
end
