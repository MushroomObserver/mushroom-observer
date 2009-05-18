require File.dirname(__FILE__) + '/../test_helper'

class InterestTest < Test::Unit::TestCase
  fixtures :interests
  fixtures :names
  fixtures :observations
  fixtures :users

  def test_setting_and_getting
    Interest.new(
      :user => @rolf,
      :object => @minimal_unknown,
      :state => true
    ).save

    Interest.new(
      :user => @mary,
      :object => @minimal_unknown,
      :state => false
    ).save

    Interest.new(
      :user => @dick,
      :object => @agaricus_campestris,
      :state => true
    ).save

    assert_equal(2, Interest.find_all_by_object(@minimal_unknown).length)
    assert_equal(1, Interest.find_all_by_object(@agaricus_campestris).length)
    assert_equal(0, Interest.find_all_by_object(@coprinus_comatus).length)

    assert_equal(1, Interest.find_all_by_user_id(@rolf.id).length)
    assert_equal(1, Interest.find_all_by_user_id(@mary.id).length)
    assert_equal(1, Interest.find_all_by_user_id(@dick.id).length)
    assert_equal(0, Interest.find_all_by_user_id(@katrina.id).length)

    assert_equal(@minimal_unknown, Interest.find_by_user_id(@rolf.id).object)
    assert_equal(@agaricus_campestris, Interest.find_by_user_id(@dick.id).object)
  end
end
