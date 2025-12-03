# frozen_string_literal: true

# Send emails directly to the observation user via the application
module Observations
  class EmailsController < ApplicationController
    include ::Emailable

    before_action :login_required

    def new
      @observation = find_or_goto_index(Observation, params[:id].to_s)
      return unless @observation && can_email_user_question?(@observation)

      respond_to do |format|
        format.html
        format.turbo_stream do
          render(
            partial: "shared/modal_form",
            locals: {
              title: :ask_observation_question_title.t(
                name: @observation.unique_format_name
              ),
              identifier: "observation_email",
              user: @user, form: "observations/emails/form"
            }
          ) and return
        end
      end
    end

    def create
      @observation = find_or_goto_index(Observation, params[:id].to_s)
      return unless @observation && can_email_user_question?(@observation)
      return unless question_present?

      # Migrated from QueuedEmail::ObserverQuestion to ActionMailer + ActiveJob.
      # See .claude/deliver_later_migration_plan.md for details.
      ObserverQuestionMailer.build(@user, @observation, question).deliver_later
      flash_notice(:runtime_ask_observation_question_success.t)

      show_flash_and_send_back
    end

    private

    def question
      params.dig(:question, :content)
    end

    def question_present?
      return true if question.present?

      flash_error(:runtime_missing.t(field: :message.l))
      render(:new)
      false
    end

    def show_flash_and_send_back
      respond_to do |format|
        format.html do
          redirect_to(observation_path(@observation.id)) and return
        end
        format.turbo_stream do
          render(partial: "shared/modal_flash_update",
                 locals: { identifier: "observation_email" }) and return
        end
      end
    end
  end
end
