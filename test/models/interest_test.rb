# frozen_string_literal: true

require "test_helper"

class InterestTest < UnitTestCase
  def test_setting_and_getting
    Interest.new(
      user: rolf,
      target: observations(:minimal_unknown_obs),
      state: true
    ).save
    Interest.new(
      user: mary,
      target: observations(:minimal_unknown_obs),
      state: false
    ).save
    Interest.new(
      user: dick,
      target: names(:agaricus_campestris),
      state: true
    ).save

    assert_equal(
      2, Interest.where_target(observations(:minimal_unknown_obs)).length
    )
    assert_equal(1, Interest.where_target(names(:agaricus_campestris)).length)
    assert_equal(0, Interest.where_target(names(:coprinus_comatus)).length)

    assert_equal(1, Interest.where(user: rolf).length)
    assert_equal(1, Interest.where(user: mary).length)
    assert_equal(1, Interest.where(user: dick).length)
    assert_equal(0, Interest.where(user: katrina).length)

    assert_equal(observations(:minimal_unknown_obs),
                 Interest.find_by(user: rolf).target)
    assert_equal(names(:agaricus_campestris),
                 Interest.find_by(user: dick).target)
  end
end
