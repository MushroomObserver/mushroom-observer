# frozen_string_literal: true

# Email sent to verify and activate a new API key.
class VerifyAPIKeyMailer < ApplicationMailer
  after_action :webmaster_delivery, only: [:build]

  def build(receiver:, app_user:, api_key:)
    setup_user(receiver)
    subject = :email_subject_verify_api_key.l
    debug_log(:verify, nil, receiver, email: receiver.email)
    mo_mail(subject,
            to: receiver,
            from: MO.accounts_email_address,
            reply_to: MO.webmaster_email_address,
            view_params: { subject:, receiver:, app_user:, api_key: })
  end
end
