# frozen_string_literal: true

require("test_helper")

class NameProposalMailerTest < MailerTestCase
  def test_build_html
    naming = namings(:coprinus_comatus_other_naming)
    observation = observations(:coprinus_comatus_obs)
    rolf.update!(email_html: true)

    mail = NameProposalMailer.build(sender: mary, receiver: rolf, naming:,
                                    observation:).message

    assert_includes(mail.to, rolf.email)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(body, "type=observations_naming")
  end

  def test_build_text
    naming = namings(:coprinus_comatus_other_naming)
    observation = observations(:coprinus_comatus_obs)
    rolf.update!(email_html: false)

    mail = NameProposalMailer.build(sender: mary, receiver: rolf, naming:,
                                    observation:).message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s, "type=observations_naming")
  end
end
