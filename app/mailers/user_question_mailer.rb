# frozen_string_literal: true

# User asking user about anything else.
class UserQuestionMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(sender:, receiver:, subject:, message:)
    setup_user(receiver)
    debug_log(:user_question, sender, receiver)
    mo_mail(subject, to: receiver, reply_to: sender,
                     view_namespace: Views::Mailers::UserQuestionMailer,
                     view_params: { subject:, sender:, receiver:,
                                    message: message || "" })
  end
end
