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
  end

  def test_build_removed
    obs = observations(:detailed_unknown_obs)
    mail = OccurrenceChangeMailer.build(
      sender: rolf, receiver: mary,
      observation: obs, action: :removed
    )
    assert_equal(1, mail.to.size)
  end
end
