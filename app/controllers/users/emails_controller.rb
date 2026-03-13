# frozen_string_literal: true

# Send emails directly to another user via the application
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
          render(Components::ModalForm.new(
                   identifier: "user_question_email",
                   title: :ask_user_question_title.t(user: @target.legal_name),
                   user: @user,
                   model: FormObject::UserQuestion.new,
                   form_locals: { target: @target }
                 ), layout: false)
        end
      end
    end

    # Migrated from QueuedEmail::UserQuestion to ActionMailer + ActiveJob.
    # See .claude/deliver_later_migration_plan.md for details.
    def create
      receiver = find_or_goto_index(User, params[:id].to_s)
      return unless receiver && can_email_user_question?(receiver)
      return missing_fields_error(receiver) if email_fields_missing?

      subject = params.dig(:user_question, :subject)
      message = params.dig(:user_question, :message)
      UserQuestionMailer.build(
        sender: @user, receiver:, subject:, message:
      ).deliver_later
      flash_notice(:runtime_ask_user_question_success.t)

      show_flash_and_send_back(receiver)
    end

    private

    def email_fields_missing?
      params.dig(:user_question, :subject).blank? ||
        params.dig(:user_question, :message).blank?
    end

    def missing_fields_error(receiver)
      flash_error(:runtime_ask_user_question_missing_fields.t)
      redirect_to(user_path(receiver.id))
    end

    def show_flash_and_send_back(receiver)
      respond_to do |format|
        format.html do
          redirect_to(user_path(receiver.id)) and return
        end
        format.turbo_stream do
          render(partial: "shared/modal_flash_update",
                 locals: { identifier: "user_question_email" }) and return
        end
      end
    end
  end
end
