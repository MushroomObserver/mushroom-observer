# frozen_string_literal: true

require("application_system_test_case")

class AccountAPIKeysSystemTest < ApplicationSystemTestCase
  def test_api_keys
    mary = users("mary")
    # Mary has one existing api key, "marys_api_key"
    marys_api_key = api_keys("marys_api_key")
    login!(mary)
    visit(account_api_keys_path)

    assert_selector("body.api_keys__index")
    within("#account_api_keys_table") do
      assert_selector("#api_key_#{marys_api_key.id}")
      # needs `as_displayed` because single quote gets converted to "smart"
      # apostrophe and encoded by `t`. Otherwise Capybara will not find the
      # HTML entity `&#8217;` and the character `’` equivalent.
      assert_selector("#notes_#{marys_api_key.id} span.current_notes",
                      text: marys_api_key.notes.t.as_displayed)
    end
    # Add a new api key
    click_button("new_key_button")
    assert_selector("#new_api_key_form")
    within("#new_api_key_form") do
      fill_in("new_api_key_notes", with: "New key idea")
      click_commit
    end

    # Should re-render the index
    assert_selector("body.api_keys__index")
    assert_flash_success(:account_api_keys_create_success.t.as_displayed)

    new_api_key = APIKey.last
    within("#account_api_keys_table") do
      assert_selector("#api_key_#{new_api_key.id}")
      assert_selector("#notes_#{new_api_key.id} span.current_notes",
                      text: "New key idea")
    end
    within("#notes_#{new_api_key.id}") do
      click_on("Edit")
    end

    assert_selector("#edit_api_key_#{new_api_key.id}_form")
    within("#edit_api_key_#{new_api_key.id}_form") do
      # Change the notes
      fill_in("api_key_#{new_api_key.id}_notes", with: "Reconsidered key idea")
      click_commit
    end

    # Should re-render the index
    assert_selector("body.api_keys__index")
    assert_flash_success(:account_api_keys_updated.t.as_displayed)

    within("#account_api_keys_table") do
      assert_selector("#api_key_#{new_api_key.id}")
      assert_selector("#notes_#{new_api_key.id} span.current_notes",
                      text: "Reconsidered key idea")
      # Remove the first api key
      accept_confirm do
        click_button("remove_api_key_#{marys_api_key.id}")
      end
    end

    # Should re-render the index
    assert_selector("body.api_keys__index")
    assert_flash_success(:account_api_keys_removed_some.t(num: 1).as_displayed)

    within("#account_api_keys_table") do
      refute_selector("#api_key_#{marys_api_key.id}")
    end

    # Activate an unverified key
    unverified = APIKey.new({ user_id: mary.id, notes: "unverified" })
    unverified.save!
    # Reload the page after this artificial intervention
    visit(account_api_keys_path)
    within("#account_api_keys_table") do
      assert_selector("#api_key_#{unverified.id}")
      click_button("activate_api_key_#{unverified.id}")
    end

    sleep(5)
    assert_selector("body.api_keys__index")
    assert_flash_success(
      :account_api_keys_activated.t(notes: unverified.notes).as_displayed
    )
  end
end
