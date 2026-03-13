# frozen_string_literal: true

require("application_system_test_case")

# Test that user fixture helper methods work in system tests
class UserFixtureHelpersSystemTest < ApplicationSystemTestCase
  def test_existing_user_helpers_still_work
    # These had explicit method definitions before
    assert_equal(users(:rolf), rolf)
    assert_equal(users(:mary), mary)
    assert_equal(users(:dick), dick)
    assert_equal(users(:katrina), katrina)
  end

  def test_new_dynamic_user_helpers_work
    # These never had explicit methods - now they work via method_missing
    assert_equal(users(:admin), admin)
    assert_equal(users(:ollie), ollie)
    assert_equal(users(:thorsten), thorsten)
    assert_equal(users(:webmaster), webmaster)
  end

  def test_nonexistent_user_raises_error
    assert_raises(StandardError) do
      nonexistent_user_xyz
    end
  end
end
