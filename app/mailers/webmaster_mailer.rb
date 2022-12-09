# frozen_string_literal: true

# User asking webmaster a question.
class WebmasterMailer < ApplicationMailer
  after_action :webmaster_delivery, only: [:build]

  def build(sender, question, subject = nil)
    I18n.locale = MO.default_locale
    @title = subject || :email_subject_webmaster_question.l(user: sender)
    @question = question
    mo_mail(@title,
            to: MO.webmaster_email_address,
            from: MO.webmaster_email_address,
            reply_to: sender,
            content_style: "plain")
  end
end
