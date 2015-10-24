# encoding: utf-8
require "test_helper"

class InterestTest < UnitTestCase
  def test_setting_and_getting
    Interest.new(
      user: rolf,
      target: observations(:minimal_unknown),
      state: true
    ).save

    Interest.new(
      user: mary,
      target: observations(:minimal_unknown),
      state: false
    ).save

    Interest.new(
      user: dick,
      target: names(:agaricus_campestris),
      state: true
    ).save
    # assert_equal(2, Interest.find_all_by_target(observations(:minimal_unknown)).length)
    assert_equal(2,
                 Interest.where_target(observations(:minimal_unknown)).length)
    # assert_equal(1, Interest.find_all_by_target(names(:agaricus_campestris)).length)
    assert_equal(1, Interest.where_target(names(:agaricus_campestris)).length)
    # assert_equal(0, Interest.find_all_by_target(names(:coprinus_comatus)).length)
    assert_equal(0, Interest.where_target(names(:coprinus_comatus)).length)

    assert_equal(1, Interest.where(user_id: rolf.id).length)
    assert_equal(1, Interest.where(user_id: mary.id).length)
    assert_equal(1, Interest.where(user_id: dick.id).length)
    assert_equal(0, Interest.where(user_id: katrina.id).length)

    assert_equal(observations(:minimal_unknown), Interest.find_by_user_id(rolf.id).target)
    assert_equal(names(:agaricus_campestris), Interest.find_by_user_id(dick.id).target)
  end
end
