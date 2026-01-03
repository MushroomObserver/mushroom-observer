# frozen_string_literal: true

require("test_helper")

# Test that user fixture helper methods work in integration tests
class UserFixtureHelpersTest < CapybaraIntegrationTestCase
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

  def test_all_user_fixtures_accessible_as_methods
    # Get all user fixture names from the loaded fixtures
    # @loaded_fixtures is set by ActiveSupport::TestCase
    user_fixture_names = @loaded_fixtures["users"].fixtures.keys

    # Verify we can access each one as a method
    user_fixture_names.each do |fixture_name|
      expected_user = users(fixture_name.to_sym)
      actual_user = send(fixture_name.to_sym)
      assert_equal(expected_user, actual_user,
                   "Helper method '#{fixture_name}' should return " \
                   "users(:#{fixture_name})")
    end
  end

  def test_nonexistent_user_raises_error
    assert_raises(StandardError) do
      nonexistent_user_xyz
    end
  end
end
