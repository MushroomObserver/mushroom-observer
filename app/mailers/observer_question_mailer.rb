# frozen_string_literal: true

# User asking user about an observation.
class ObserverQuestionMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(sender:, observation:, message:)
    setup_user(observation.user)
    name = observation.unique_text_name
    @title = :email_subject_observation_question.l(name:)
    @sender = sender
    @observation = observation
    @message = message || ""
    debug_log(:observation_question, sender, @user, observation:)
    mo_mail(@title, to: @user, reply_to: sender)
  end
end
