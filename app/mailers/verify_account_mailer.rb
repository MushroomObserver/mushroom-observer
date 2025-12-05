# frozen_string_literal: true

# Email sent to verify user's email.
class VerifyAccountMailer < ApplicationMailer
  after_action :webmaster_delivery, only: [:build]

  def build(receiver:)
    setup_user(receiver)
    @title = :email_subject_verify.l
    debug_log(:user_question, nil, receiver, email: receiver.email)
    mo_mail(@title, to: receiver, from: MO.accounts_email_address)
  end
end
