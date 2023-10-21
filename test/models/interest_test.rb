# frozen_string_literal: true

require("test_helper")

class InterestTest < UnitTestCase
  def test_setting_and_getting
    # NOTE: All users already have an interest in a NameTracker fixture
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

    assert_equal("NameTracker", Interest.where(user: rolf).first.target_type)
    assert_equal("NameTracker", Interest.where(user: mary).first.target_type)
    assert_equal("NameTracker", Interest.where(user: dick).first.target_type)
    assert_equal("NameTracker", Interest.where(user: katrina).first.target_type)
    assert_equal(2, Interest.where(user: rolf).length)
    assert_equal(2, Interest.where(user: mary).length)
    assert_equal(2, Interest.where(user: dick).length)
    assert_equal(1, Interest.where(user: katrina).length)

    assert_equal(observations(:minimal_unknown_obs),
                 Interest.where(user: rolf).last.target)
    assert_equal(names(:agaricus_campestris),
                 Interest.where(user: dick).last.target)

    assert_equal(true, dick.watching?(names(:agaricus_campestris)))
  end
end
