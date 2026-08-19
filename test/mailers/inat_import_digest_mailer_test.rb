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

  def test_build_defaults_total_observations_to_the_namings_given
    rolf.update!(email_html: true)
    naming = namings(:coprinus_comatus_other_naming)

    mail = InatImportDigestMailer.build(receiver: rolf, namings: [naming]).
           message

    # No total_observations passed -> subject falls back to counting the
    # (untruncated) namings array itself, and no truncation note appears.
    assert_includes(mail.subject, "1")
    assert_not_includes(
      mail.body.to_s,
      :email_inat_import_digest_truncated.l(shown: 1, count: 1)
    )
  end

  def test_build_reports_truncation_when_total_exceeds_namings_given
    rolf.update!(email_html: true)
    naming = namings(:coprinus_comatus_other_naming)

    mail = InatImportDigestMailer.build(
      receiver: rolf, namings: [naming], total_observations: 3
    ).message

    assert_includes(mail.subject, "3")
    assert_includes(
      mail.body.to_s,
      :email_inat_import_digest_truncated.l(shown: 1, count: 3)
    )
  end
end
