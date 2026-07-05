# frozen_string_literal: true

require("test_helper")

class CommentMailerTest < MailerTestCase
  def test_comment_owner_html
    target = observations(:minimal_unknown_obs)
    comment = comments(:minimal_unknown_obs_comment_1)
    mary.update!(email_html: true)

    mail = build_comment(sender: rolf, receiver: mary, target:, comment:,
                         email_type: "owner").message

    assert_equal("[MO] #{:email_subject_comment.l(
      name: target.unique_text_name
    )}", mail.subject)
    assert_includes(mail.to, mary.email)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(body, comment.summary)
    assert_includes(body, comment.comment.tp)
    assert_includes(body,
                    "https://mushroomobserver.org/observations/#{target.id}")
    assert_includes(body, "type=comments_owner")
  end

  def test_comment_owner_text
    target = observations(:minimal_unknown_obs)
    comment = comments(:minimal_unknown_obs_comment_1)
    mary.update!(email_html: false)

    mail = build_comment(sender: rolf, receiver: mary, target:, comment:,
                         email_type: "owner").message

    assert_text_mail(mail)
    body = mail.body.to_s
    assert_includes(body, "-" * 50)
    assert_includes(body, comment.summary)
    assert_includes(body, comment.comment.tp.html_to_ascii)
    assert_includes(body, "type=comments_owner")
  end

  def test_comment_response_html
    target = observations(:minimal_unknown_obs)
    comment = comments(:minimal_unknown_obs_comment_2)
    rolf.update!(email_html: true)

    mail = build_comment(sender: dick, receiver: rolf, target:, comment:,
                         email_type: "response").message

    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(body, :email_comment_intro_response.l(
      type: target.type_tag, name: target.unique_format_name
    ).tp)
    assert_includes(body, "type=comments_response")
  end

  def test_comment_response_text
    target = observations(:minimal_unknown_obs)
    comment = comments(:minimal_unknown_obs_comment_2)
    rolf.update!(email_html: false)

    mail = build_comment(sender: dick, receiver: rolf, target:, comment:,
                         email_type: "response").message

    assert_text_mail(mail)
    body = mail.body.to_s
    assert_includes(body, comment.comment.tp.html_to_ascii)
    assert_includes(body, "type=comments_response")
  end

  private

  def build_comment(**args)
    CommentMailer.build(**args)
  end
end
