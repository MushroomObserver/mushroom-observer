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

  def test_polymorphic_joins
    Interest::ALL_TYPE_TAGS.each do |type_tag|
      assert_true(Interest.joins(type_tag))
    end
  end

  def test_validate_missing_user
    interest = Interest.new(
      target: observations(:minimal_unknown_obs),
      state: true
    )

    assert_not(interest.save)
    assert_includes(interest.errors[:user],
                    :validate_interest_user_missing.t)
  end

  def test_validate_target_type_too_long
    interest = Interest.new(
      user: rolf,
      target: observations(:minimal_unknown_obs),
      state: true
    )
    interest.target_type = "A" * 31

    assert_not(interest.save)
    assert_includes(interest.errors[:target_type],
                    :validate_interest_object_type_too_long.t)
  end

  def test_target_format_name_without_viewer_aware_method
    interest = Interest.new(
      user: rolf, target: locations(:albion), state: true
    )

    assert_not(locations(:albion).respond_to?(:user_unique_format_name))
    assert_equal(locations(:albion).unique_format_name,
                 interest.target_format_name)
  end
end
