# frozen_string_literal: true

# Admins sending approval of a user's request.
class ApprovalMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(receiver:, subject:, message:)
    setup_user(receiver)
    @title = subject
    @message = message
    debug_log(:approval, ::User.admin, receiver)
    mo_mail(@title, to: receiver, reply_to: MO.webmaster_email_address)
  end
end
