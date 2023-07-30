# frozen_string_literal: true

# Send emails directly to the observation user via the application
module Observations
  class EmailsController < ApplicationController
    include ::Emailable

    before_action :login_required

    def new
      @observation = find_or_goto_index(Observation, params[:id].to_s)
      return unless @observation && can_email_user_question?(@observation)
    end

    def create
      @observation = find_or_goto_index(Observation, params[:id].to_s)
      return unless @observation && can_email_user_question?(@observation)

      question = params.dig(:question, :content)
      ObservationMailer.build(@user, @observation, question).deliver_now
      flash_notice(:runtime_ask_observation_question_success.t)

      show_flash_and_send_back
    end

    private

    def show_flash_and_send_back
      respond_to do |format|
        format.html do
          redirect_with_query(observation_path(@observation.id)) and return
        end
        format.js do
          # renders the flash in the modal via js
          render(partial: "shared/modal_update_flash") and return
        end
      end
    end
  end
end
