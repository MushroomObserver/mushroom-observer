# frozen_string_literal: true

# Admins sending approval of a user's request.
class ApprovalMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(user, subject, content)
    setup_user(user)
    @title = subject
    @message = content
    debug_log(:approval, ::User.admin, user)
    mo_mail(@title, to: user, reply_to: MO.webmaster_email_address)
  end
end
