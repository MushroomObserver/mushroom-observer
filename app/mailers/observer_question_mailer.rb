# frozen_string_literal: true

# User asking user about an observation.
class ObserverQuestionMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(sender:, observation:, message:)
    setup_user(observation.user)
    subject = :email_subject_observation_question.l(
      name: observation.unique_text_name
    )
    debug_log(:observation_question, sender, @user, observation:)
    mo_mail(subject, to: @user, reply_to: sender,
                     view_namespace: Views::Mailers::ObserverQuestionMailer,
                     view_params: { subject:, sender:, receiver: @user,
                                    observation:, message: message || "" })
  end
end
