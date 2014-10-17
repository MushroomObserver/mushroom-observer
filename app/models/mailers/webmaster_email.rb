# User asking webmaster a question.
class WebmasterEmail < AccountMailer
  def build(sender, question)
    I18n.locale = MO.default_locale
    @title = :email_subject_webmaster_question.l(user: sender)
    @question = question
    mo_mail(@title,
            to: MO.webmaster_email_address,
            from: MO.webmaster_email_address,
            reply_to: sender,
            content_style: "plain")
  end
end
