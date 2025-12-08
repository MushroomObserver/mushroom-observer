# frozen_string_literal: true

# User asking user about anything else.
class UserQuestionMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(sender:, receiver:, subject:, message:)
    setup_user(receiver)
    @title = subject
    @sender = sender
    @message = message || ""
    debug_log(:user_question, sender, receiver)
    mo_mail(@title, to: receiver, reply_to: sender)
  end
end
