# frozen_string_literal: true

require("test_helper")

class OccurrenceChangeMailerTest < UnitTestCase
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
    assert(mail.respond_to?(:deliver_now),
           "Mail should be deliverable")
    assert_not_nil(mail.from)
    assert_not_nil(mail.body)
  end
end
