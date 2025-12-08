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
              user: @user,
              form: "observations/emails/form",
              form_locals: {
                model: FormObject::ObserverQuestion.new,
                observation: @observation
              }
            }
          ) and return
        end
      end
    end

    def create
      observation = find_or_goto_index(Observation, params[:id].to_s)
      return unless observation && can_email_user_question?(observation)
      return unless message_present?(observation)

      # Migrated from QueuedEmail::ObserverQuestion to ActionMailer + ActiveJob.
      message = params.dig(:observer_question, :message)
      ObserverQuestionMailer.build(
        sender: @user, observation:, message:
      ).deliver_later
      flash_notice(:runtime_ask_observation_question_success.t)

      show_flash_and_send_back(observation)
    end

    private

    def message_present?(observation)
      return true if params.dig(:observer_question, :message).present?

      flash_error(:runtime_missing.t(field: :message.l))
      @observation = observation
      render(:new)
      false
    end

    def show_flash_and_send_back(observation)
      respond_to do |format|
        format.html do
          redirect_to(observation_path(observation.id)) and return
        end
        format.turbo_stream do
          render(partial: "shared/modal_flash_update",
                 locals: { identifier: "observation_email" }) and return
        end
      end
    end
  end
end
