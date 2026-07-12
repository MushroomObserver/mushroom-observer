# frozen_string_literal: true

require("test_helper")

class InatImportDigestMailerTest < MailerTestCase
  def test_build_html
    rolf.update!(email_html: true)
    naming = namings(:coprinus_comatus_other_naming)

    mail = InatImportDigestMailer.build(receiver: rolf, namings: [naming]).
           message

    assert_includes(mail.to, rolf.email)
    assert_html_mail(mail)
    body = mail.body.to_s
    # observation link and the interests-management link both present
    assert_includes(body, "#{MO.http_domain}/#{naming.observation_id}")
    assert_includes(body, "#{MO.http_domain}/interests")
  end

  def test_build_text
    rolf.update!(email_html: false)
    naming = namings(:coprinus_comatus_other_naming)

    mail = InatImportDigestMailer.build(receiver: rolf, namings: [naming]).
           message

    assert_text_mail(mail)
    # the observation url survives into the text part (not just the anchor)
    assert_includes(mail.body.to_s,
                    "#{MO.http_domain}/#{naming.observation_id}")
  end
end
