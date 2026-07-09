# frozen_string_literal: true

require("test_helper")

class ConsensusChangeMailerTest < MailerTestCase
  def test_build_html
    observation = observations(:coprinus_comatus_obs)
    old_name = names(:agaricus_campestris)
    new_name = observation.name
    mary.update!(email_html: true)

    mail = ConsensusChangeMailer.build(sender: dick, receiver: mary,
                                       observation:, old_name:,
                                       new_name:).message

    assert_includes(mail.to, mary.email)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(body, "https://mushroomobserver.org/#{observation.id}")
    assert_includes(body, "type=observations_consensus")
  end

  def test_build_text
    observation = observations(:coprinus_comatus_obs)
    old_name = names(:agaricus_campestris)
    new_name = observation.name
    mary.update!(email_html: false)

    mail = ConsensusChangeMailer.build(sender: dick, receiver: mary,
                                       observation:, old_name:,
                                       new_name:).message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s, "type=observations_consensus")
  end

  def test_build_no_old_name
    observation = observations(:coprinus_comatus_obs)
    mary.update!(email_html: false)

    mail = ConsensusChangeMailer.build(sender: dick, receiver: mary,
                                       observation:, old_name: nil,
                                       new_name: observation.name).message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s, "--")
  end
end
