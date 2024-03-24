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
              locals: { identifier: "webmaster_question_email",
                        title: :ask_webmaster_title.l,
                        form: "admin/email/webmaster_questions/form" }
            ) and return
          end
        end
      end

      def create
        @email = params.dig(:user, :email)
        @content = params.dig(:question, :content)
        @email_error = false
        create_webmaster_question
      end

      private

      def create_webmaster_question
        if @email.blank? || @email.index("@").nil?
          flash_error(:runtime_ask_webmaster_need_address.t)
          @email_error = true
        elsif @content.blank?
          flash_error(:runtime_ask_webmaster_need_content.t)
        elsif non_user_potential_spam?
          flash_error(:runtime_ask_webmaster_antispam.t)
        else
          QueuedEmail::Webmaster.create_email(sender_email: @email,
                                              content: @content)
          flash_notice(:runtime_ask_webmaster_success.t)
          redirect_to("/")
        end
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
