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
          render(
            partial: "shared/modal_form",
            locals: {
              title: :ask_user_question_title.t(user: @target.legal_name),
              identifier: "user_question_email",
              user: @user, form: "users/emails/form"
            }
          ) and return
        end
      end
    end

    def create
      @target = find_or_goto_index(User, params[:id].to_s)
      return unless @target && can_email_user_question?(@target)
      return redirect_with_missing_fields_error unless email_fields_present?

      UserQuestionMailer.build(@user, @target, subject, content).deliver_later
      flash_notice(:runtime_ask_user_question_success.t)

      show_flash_and_send_back
    end

    private

    def subject
      params.dig(:email, :subject)
    end

    def content
      params.dig(:email, :content)
    end

    def email_fields_present?
      subject.present? && content.present?
    end

    def redirect_with_missing_fields_error
      flash_error(:runtime_ask_user_question_missing_fields.t)
      redirect_to(user_path(@target.id))
    end

    def show_flash_and_send_back
      respond_to do |format|
        format.html do
          redirect_to(user_path(@target.id)) and return
        end
        format.turbo_stream do
          render(partial: "shared/modal_flash_update",
                 locals: { identifier: "user_question_email" }) and return
        end
      end
    end
  end
end
