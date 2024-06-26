# frozen_string_literal: true

# Email sent to verify and activate a new API key.
class VerifyAPIKeyMailer < ApplicationMailer
  after_action :webmaster_delivery, only: [:build]

  def build(user, app_user, api_key)
    setup_user(user)
    @title = :email_subject_verify_api_key.l
    @app_user = app_user
    @api_key = api_key
    debug_log(:verify, nil, user, email: user.email)
    mo_mail(@title,
            to: user,
            from: MO.accounts_email_address,
            reply_to: MO.webmaster_email_address)
  end
end
