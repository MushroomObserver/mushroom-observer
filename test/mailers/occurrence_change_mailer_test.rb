# frozen_string_literal: true

require("test_helper")

class OccurrenceChangeMailerTest < MailerTestCase
  include ActiveJob::TestHelper

  def test_build_added
    obs = observations(:detailed_unknown_obs)
    mail = OccurrenceChangeMailer.build(
      sender: rolf, receiver: mary,
      observation: obs, action: :added
    )
    assert_equal(1, mail.to.size)
    assert_includes(mail.to, mary.email)
    assert_not_nil(mail.subject)
    assert_not_empty(mail.subject)
  end

  def test_build_removed
    obs = observations(:detailed_unknown_obs)
    mail = OccurrenceChangeMailer.build(
      sender: rolf, receiver: mary,
      observation: obs, action: :removed
    )
    assert_equal(1, mail.to.size)
    assert_includes(mail.to, mary.email)
    assert_not_nil(mail.subject)
    assert_not_empty(mail.subject)
  end

  def test_build_delivers_email
    obs = observations(:detailed_unknown_obs)
    mail = OccurrenceChangeMailer.build(
      sender: rolf, receiver: mary,
      observation: obs, action: :added
    )
    assert_respond_to(mail, :deliver_now,
                      "Mail should be deliverable")
    assert_not_nil(mail.from)
    assert_not_nil(mail.body)
  end

  # occurrence_link only emits a link when the observation actually
  # has an occurrence_id — the fixture otherwise has none.
  def test_build_with_occurrence_link
    obs = observations(:detailed_unknown_obs)
    occurrence = occurrences(:occ_field_slip_one)
    obs.update!(occurrence_id: occurrence.id)

    mail = OccurrenceChangeMailer.build(
      sender: rolf, receiver: mary, observation: obs, action: :added
    ).message

    assert_includes(mail.body.to_s,
                    "https://mushroomobserver.org/occurrences/#{occurrence.id}")
  end
end
