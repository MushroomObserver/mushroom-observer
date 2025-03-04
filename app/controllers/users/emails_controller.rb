# frozen_string_literal: true

# Send emails directly to the observation user via the application
module Users
  class EmailsController < ApplicationController
    include ::Emailable

    before_action :login_required

    def new
      @target = find_or_goto_index(User, params[:id].to_s)
      return unless @target && can_email_user_question?(@target)

      respond_to do |format|
        format.html
        format.turbo_stream do
          render(partial: "shared/modal_form",
                 locals: { identifier: "user_question_email",
                           title: :ask_user_question_title.t(
                             user: @target.legal_name
                           ),
                           form: "users/emails/form" }) and return
        end
      end
    end

    def create
      @target = find_or_goto_index(User, params[:id].to_s)
      return unless @target && can_email_user_question?(@target)

      subject = params.dig(:email, :subject)
      content = params.dig(:email, :content)
      QueuedEmail::UserQuestion.create_email(@user, @target, subject, content)
      flash_notice(:runtime_ask_user_question_success.t)

      show_flash_and_send_back
    end

    private

    def show_flash_and_send_back
      respond_to do |format|
        format.html do
          redirect_with_query(user_path(@target.id)) and return
        end
        format.turbo_stream do
          render(partial: "shared/modal_flash_update",
                 locals: { identifier: "user_question_email" }) and return
        end
      end
    end
  end
end
