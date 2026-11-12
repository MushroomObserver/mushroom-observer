# frozen_string_literal: true

require("test_helper")

class PasswordMailerTest < MailerTestCase
  def test_build_html
    rolf.update!(email_html: true)

    mail = PasswordMailer.build(receiver: rolf, password: "A password").message

    assert_includes(mail.to, rolf.email)
    assert_equal(MO.accounts_email_address, mail.from.first)
    assert_html_mail(mail)
    assert_includes(mail.body.to_s, "A password")
  end

  # ActiveJob logs its arguments, and this mailer is handed a cleartext
  # password, so the delivery job has to be the quiet one.
  def test_delivery_job_keeps_arguments_out_of_the_log
    assert_equal(QuietMailDeliveryJob, PasswordMailer.delivery_job)
    assert_not(QuietMailDeliveryJob.log_arguments)
  end

  def test_build_text
    rolf.update!(email_html: false)

    mail = PasswordMailer.build(receiver: rolf, password: "A password").message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s, "A password")
  end
end
