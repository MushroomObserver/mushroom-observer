# frozen_string_literal: true

require("test_helper")

# Test that all user fixtures are accessible via helper methods.
# This validates that fixture names follow Ruby method naming conventions.
class UserFixtureAccessibilityTest < UnitTestCase
  def test_all_user_fixtures_are_accessible_as_methods
    # Get all user fixture names
    user_fixture_names = @loaded_fixtures["users"].fixtures.keys
    inaccessible_fixtures = []

    # Check each fixture
    user_fixture_names.each do |fixture_name|
      # Try to access it as a method
      unless valid_ruby_method_name?(fixture_name)
        inaccessible_fixtures << fixture_name
      end
    end

    # If any fixtures are inaccessible, fail with a helpful message
    if inaccessible_fixtures.any?
      fixture_list = inaccessible_fixtures.map do |name|
        "  - #{name}"
      end.join("\n")
      flunk(
        "Some user fixtures cannot be accessed as helper methods:\n" \
        "#{fixture_list}\n\n" \
        "Fixture names must be valid Ruby method names (lowercase letters, " \
        "digits, and underscores only, starting with a lowercase letter or " \
        "underscore).\n\n" \
        "To fix this, rename these fixtures to use only lowercase letters, " \
        "digits, and underscores.\n\n" \
        "Example: Instead of 'My-User', use 'my_user'"
      )
    end

    # Also verify we can actually call each one
    user_fixture_names.each do |fixture_name|
      expected_user = users(fixture_name.to_sym)
      actual_user = send(fixture_name.to_sym)
      assert_equal(expected_user, actual_user,
                   "Helper method '#{fixture_name}' should return " \
                   "users(:#{fixture_name})")
    end
  end

  private

  # Check if a string is a valid Ruby method name
  def valid_ruby_method_name?(name)
    # Ruby method names must:
    # - Start with lowercase letter or underscore
    # - Contain only lowercase letters, digits, and underscores
    # - Optionally end with ? or ! (not applicable for our use case)
    name.to_s.match?(/\A[a-z_][a-z0-9_]*\z/)
  end
end
