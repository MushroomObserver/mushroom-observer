# frozen_string_literal: true

module Admin
  module Emails
    # NOTE: Does not inherit from AdminController
    class WebmasterQuestionsController < ApplicationController
      def new
        @email = params.dig(:user, :email)
        @message = params.dig(:question, :message)
        @email = @user.email if @user

        respond_to do |format|
          format.html { render_new_page }
          format.turbo_stream do
            render(Components::Modal::TurboForm.new(
                     identifier: "webmaster_question_email",
                     title: :ask_webmaster_title.l,
                     user: @user,
                     model: FormObject::EmailRequest.new(
                       reply_to: @email, message: @message
                     ),
                     form_class: Views::Controllers::Admin::Emails::WebmasterQuestions::Form,
                     form_locals: { email_error: false }
                   ), layout: false)
          end
        end
      end

      def create
        @email = params.dig(:email, :reply_to)
        @message = params.dig(:email, :message)
        @email_error = false
        create_webmaster_question
      end

      private

      def create_webmaster_question
        if invalid_email?
          handle_invalid_email
        elsif @message.blank?
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
        render_new_page
      end

      def handle_missing_content
        flash_error(:runtime_ask_webmaster_need_content.t)
        render_new_page
      end

      def handle_spam
        flash_error(:runtime_ask_webmaster_antispam.t)
        render_new_page
      end

      def render_new_page
        render(Views::Controllers::Admin::Emails::WebmasterQuestions::New.new(
                 email: @email, message: @message, email_error: @email_error
               ))
      end

      def send_email_and_redirect
        # Migrated from QueuedEmail::Webmaster to ActionMailer + ActiveJob.
        message = WebmasterMailer.prepend_user(@user, @message)
        WebmasterMailer.build(sender_email: @email, message:).
          deliver_later
        flash_notice(:runtime_ask_webmaster_success.t)
        redirect_to("/")
      end

      def non_user_potential_spam?
        !@user && (
          /https?:/.match?(@message) ||
          %r{<[/a-zA-Z]+>}.match?(@message) ||
          @message.exclude?(" ")
        )
      end
    end
  end
end
