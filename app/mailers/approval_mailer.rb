# frozen_string_literal: true

# Admins sending approval of a user's request.
class ApprovalMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(receiver:, subject:, message:)
    setup_user(receiver)
    debug_log(:approval, ::User.admin, receiver)
    mo_mail(subject, to: receiver, reply_to: MO.webmaster_email_address,
                     view_params: { message: })
  end
end
