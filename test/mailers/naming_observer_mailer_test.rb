# frozen_string_literal: true

require("test_helper")

class NamingObserverMailerTest < MailerTestCase
  def test_build_html
    naming = namings(:agaricus_campestris_naming)
    name_tracker = name_trackers(:agaricus_campestris_name_tracker_with_note)
    rolf.update!(email_html: true)

    mail = NamingObserverMailer.build(receiver: rolf, naming:,
                                      name_tracker:).message

    assert_includes(mail.to, rolf.email)
    assert_equal(name_tracker.user.email, mail.reply_to.first)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(body,
                    "https://mushroomobserver.org/#{naming.observation_id}")
  end

  def test_build_text
    naming = namings(:agaricus_campestris_naming)
    name_tracker = name_trackers(:agaricus_campestris_name_tracker_with_note)
    rolf.update!(email_html: false)

    mail = NamingObserverMailer.build(receiver: rolf, naming:,
                                      name_tracker:).message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s, "-" * 50)
  end

  def test_build_skips_unapproved_tracker
    naming = namings(:agaricus_campestris_naming)
    name_tracker = name_trackers(:agaricus_campestris_name_tracker_with_note)
    name_tracker.update!(approved: false)
    ActionMailer::Base.deliveries = []

    NamingObserverMailer.build(receiver: rolf, naming:,
                               name_tracker:).deliver_now

    assert_nil(ActionMailer::Base.deliveries.last)
  end
end
