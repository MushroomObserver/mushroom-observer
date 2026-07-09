# frozen_string_literal: true

require("test_helper")

class CommercialInquiryMailerTest < MailerTestCase
  def test_build_html
    image = images(:commercial_inquiry_image)
    image.user.update!(email_html: true)

    mail = CommercialInquiryMailer.build(
      sender: mary, image:, message: "Did test_commercial_inquiry work?"
    ).message

    assert_includes(mail.to, image.user.email)
    assert_equal(mary.email, mail.reply_to.first)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(body, "Did test_commercial_inquiry work?")
    assert_includes(body, "https://mushroomobserver.org/images/#{image.id}")
  end

  def test_build_text
    image = images(:commercial_inquiry_image)
    image.user.update!(email_html: false)

    mail = CommercialInquiryMailer.build(
      sender: mary, image:, message: "Did test_commercial_inquiry work?"
    ).message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s, "Did test_commercial_inquiry work?")
  end
end
