# frozen_string_literal: true

require("test_helper")

class ContentPurgeMailerTest < MailerTestCase
  INAT_URL = "https://www.inaturalist.org/observations/5000"

  def test_build_text_for_an_excluded_inat_user
    rolf.update!(email_html: false)
    purge = ContentPurge.new(inat_login: "someone_on_inat")

    mail = ContentPurgeMailer.build(receiver: rolf, purge: purge,
                                    entries: entries).message

    assert_text_mail(mail)
    body = mail.body.to_s
    assert_includes(body,
                    :content_purge_inat_holder.l(login: "someone_on_inat"))
    assert_includes(body, "Observation 1: #{MO.http_domain}/obs/1")
    assert_includes(body, "#{:content_purge_email_source.l} #{INAT_URL}")
    assert_includes(body, :content_purge_email_no_source.l)
  end

  def test_build_html_for_an_mo_user
    rolf.update!(email_html: true)
    purge = ContentPurge.new(target_user: mary)

    mail = ContentPurgeMailer.build(receiver: rolf, purge: purge,
                                    entries: entries).message

    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(body, mary.login)
    assert_includes(body, "href=\"#{INAT_URL}\"")
    assert_includes(body, "href=\"#{MO.http_domain}/obs/1\"")
  end

  private

  def entries
    [{ image_id: 10, copyright_holder: "(c) Some One",
       content: [["Observation 1", "#{MO.http_domain}/obs/1"]],
       source_url: INAT_URL },
     { image_id: 11, copyright_holder: "Some One",
       content: [["Observation 2", "#{MO.http_domain}/obs/2"]],
       source_url: nil }]
  end
end
