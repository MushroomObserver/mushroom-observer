# Email sent to admins when sign-up is denied.
class DeniedEmail < AccountMailer
  def build(user_params)
    I18n.locale = MO.default_locale
    @title = :email_subject_denied.l
    @user_params = user_params
    mo_mail(@title,
            from: MO.accounts_email_address,
            to: MO.webmaster_email_address,
            content_style: "plain")
  end
end
