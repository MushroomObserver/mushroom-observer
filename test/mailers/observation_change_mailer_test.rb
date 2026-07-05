# frozen_string_literal: true

require("test_helper")

class ObservationChangeMailerTest < MailerTestCase
  def test_build_change_html
    observation = observations(:coprinus_comatus_obs)
    note = "date,location,specimen,is_collection_location,notes," \
           "thumb_image_id,added_image,removed_image"
    mary.update!(email_html: true)

    mail = ObservationChangeMailer.build(
      sender: dick, receiver: mary, observation:, note:,
      time: observation.created_at
    ).message

    assert_includes(mail.to, mary.email)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(body, observation.place_name)
  end

  def test_build_change_text
    observation = observations(:coprinus_comatus_obs)
    note = "date,location,specimen,is_collection_location,notes," \
           "thumb_image_id,added_image,removed_image"
    mary.update!(email_html: false)

    mail = ObservationChangeMailer.build(
      sender: dick, receiver: mary, observation:, note:,
      time: observation.created_at
    ).message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s, observation.place_name)
  end

  def test_build_destroy_html
    observation = observations(:coprinus_comatus_obs)
    note = "**__Coprinus comatus__** L. (123)"
    mary.update!(email_html: true)

    mail = ObservationChangeMailer.build(
      sender: dick, receiver: mary, observation: nil, note:,
      time: observation.created_at
    ).message

    assert_html_mail(mail)
    assert_includes(mail.body.to_s, :email_observation_destroyed_intro.l.tp)
  end

  def test_build_destroy_text
    observation = observations(:coprinus_comatus_obs)
    note = "**__Coprinus comatus__** L. (123)"
    mary.update!(email_html: false)

    mail = ObservationChangeMailer.build(
      sender: dick, receiver: mary, observation: nil, note:,
      time: observation.created_at
    ).message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s, "Coprinus comatus")
  end
end
