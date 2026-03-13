# frozen_string_literal: true

require("test_helper")

# Simple smoke tests for API key form submission
class APIKeysIntegrationTest < CapybaraIntegrationTestCase
  def test_create_api_key
    # Login as a user
    login(users(:rolf))

    # Visit the API keys index page and click new
    visit(account_api_keys_path)
    assert_selector("body.api_keys__index")

    # Count existing keys
    initial_count = APIKey.where(user: users(:rolf)).count

    # Fill in the form with valid data
    fill_in("api_key_notes", with: "Test API Key")

    # Submit the form
    within("form[action='/account/api_keys']") do
      click_commit
    end

    # Verify successful creation (stays on index page with new key)
    assert_selector("body.api_keys__index")

    # Verify database effect
    assert_equal(initial_count + 1, APIKey.where(user: users(:rolf)).count)
    key = APIKey.where(user: users(:rolf)).last
    assert_equal("Test API Key", key.notes)
  end

  def test_edit_api_key
    # Login as a user
    user = users(:rolf)
    login(user)

    # Use existing fixture key
    key = api_keys(:rolfs_api_key)
    original_notes = key.notes

    # Visit the API keys index page
    visit(account_api_keys_path)
    assert_selector("body.api_keys__index")

    # Click the edit button to expand the edit form
    within("#notes_#{key.id}") do
      find("button[data-role='edit_api_key']").click
    end

    # Fill in the notes field
    fill_in("api_key_#{key.id}_notes", with: "Updated API key notes")

    # Submit the form
    within("#edit_notes_#{key.id}_container form") do
      click_button(:SAVE.l)
    end

    # Verify successful update (stays on index page)
    assert_selector("body.api_keys__index")

    # Verify database effect
    key.reload
    assert_equal("Updated API key notes", key.notes)
    assert_not_equal(original_notes, key.notes)
  end
end
