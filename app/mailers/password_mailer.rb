# frozen_string_literal: true

# User forgot their password.
class PasswordMailer < ApplicationMailer
  # The cleartext password is one of this mailer's job arguments.
  self.delivery_job = QuietMailDeliveryJob

  after_action :webmaster_delivery, only: [:build]

  def build(receiver:, password:)
    setup_user(receiver)
    subject = :email_subject_new_password.l
    debug_log(:new_password, nil, @user)
    mo_mail(subject, to: receiver, from: MO.accounts_email_address,
                     view_params: { subject:, receiver:, password: })
  end
end
