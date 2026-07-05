# frozen_string_literal: true

require("test_helper")

class VerifyAPIKeyMailerTest < MailerTestCase
  def test_build_html
    api_key = api_keys(:rolfs_api_key)
    rolf.update!(email_html: true)

    mail = VerifyAPIKeyMailer.build(receiver: rolf, app_user: dick,
                                    api_key:).message

    assert_includes(mail.to, rolf.email)
    assert_equal(MO.accounts_email_address, mail.from.first)
    assert_equal(MO.webmaster_email_address, mail.reply_to.first)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(body, dick.login)
    assert_includes(body, api_key.notes)
  end

  def test_build_text
    api_key = api_keys(:rolfs_api_key)
    rolf.update!(email_html: false)

    mail = VerifyAPIKeyMailer.build(receiver: rolf, app_user: dick,
                                    api_key:).message

    assert_text_mail(mail)
    body = mail.body.to_s
    assert_includes(body, dick.login)
    assert_includes(body, api_key.notes)
  end
end
