# frozen_string_literal: true

# Custom mailer for sending recovery emails to users whose accounts
# were affected by the verification email outage (Jan 14 - Feb 17, 2026).
#
# Uses news_delivery (gmail_smtp_settings_news) since the webmaster
# credentials were broken during this period.
class AccountRecoveryMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(receiver:, subject:, body:)
    setup_user(receiver)
    @title = subject
    @body = body
    debug_log(:account_recovery, nil, receiver, email: receiver.email)
    mo_mail(@title, to: receiver, from: MO.accounts_email_address)
  end
end
