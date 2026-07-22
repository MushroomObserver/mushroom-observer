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

  # No-JS create fallback. The "+ Add Key" button on the index is a
  # real `<a href=/new>` link; with JS, Bootstrap collapse intercepts
  # the click. Without JS (rack-test driver), the link navigates to
  # the standalone create page.
  def test_create_api_key_via_no_js_fallback
    user = users(:rolf)
    login(user)
    initial_count = APIKey.where(user: user).count

    visit(account_api_keys_path)
    # Click the "+ Add Key" link (rack-test ignores data-toggle and
    # follows the href).
    click_link(id: "new_key_button")
    # Should have landed on the standalone new page.
    assert_selector("body.api_keys__new")

    fill_in("api_key_notes", with: "No-JS test key")
    within("form#new_api_key_form") { click_commit }

    # Create redirects back to the index.
    assert_selector("body.api_keys__index")
    assert_equal(initial_count + 1, APIKey.where(user: user).count)
    assert_equal("No-JS test key", APIKey.where(user: user).last.notes)
  end

  # Standalone edit page's Cancel link should navigate back to the
  # index without modifying anything. (Pre-Phlex, Cancel was a
  # submit button that paradoxically ran an update.)
  def test_edit_api_key_cancel_link_does_not_modify
    user = users(:rolf)
    login(user)
    key = api_keys(:rolfs_api_key)
    original_notes = key.notes

    visit(edit_account_api_key_path(key.id))
    # Type something into the notes field (which should NOT be saved).
    fill_in("api_key_notes", with: "Should not save this")

    click_link(:cancel.ti)

    # Cancel navigates back to the index, and the key's notes are
    # unchanged.
    assert_selector("body.api_keys__index")
    assert_equal(original_notes, key.reload.notes)
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
      find("a[data-role='edit_api_key']").click
    end

    # Fill in the notes field
    fill_in("api_key_#{key.id}_notes", with: "Updated API key notes")

    # Submit the form
    within("#edit_notes_#{key.id}_container form") do
      click_button(:save.ti)
    end

    # Verify successful update (stays on index page)
    assert_selector("body.api_keys__index")

    # Verify database effect
    key.reload
    assert_equal("Updated API key notes", key.notes)
    assert_not_equal(original_notes, key.notes)
  end
end
