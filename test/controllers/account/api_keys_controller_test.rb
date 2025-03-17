# frozen_string_literal: true

require("test_helper")

# tests of Account API Keys controller
module Account
  class APIKeysControllerTest < FunctionalTestCase
    def test_api_key_manager
      APIKey.find_each(&:destroy)
      assert_equal(0, APIKey.count)

      # Get initial (empty) form.
      requires_login("index")
      assert_select("[data-role='edit_api_key']", count: 0)
      assert_select(".current_notes", count: 0)

      # Try to create key with no name.
      login("mary")
      post(:create, params: {})
      assert_flash_error
      assert_equal(0, APIKey.count)
      assert_select("[data-role='edit_api_key']", count: 0)

      # Create good key.
      post(:create, params: { api_key: { notes: "app name" } })
      assert_flash_success
      assert_equal(1, APIKey.count)
      assert_equal(1, mary.reload.api_keys.length)
      key1 = mary.api_keys.first
      assert_equal("app name", key1.notes)
      assert_redirected_to(action: "index")
      get("index") # It doesn't follow the redirect.
      assert_select("[data-role='edit_api_key']", count: 1)

      # Create another key.
      post(:create, params: { api_key: { notes: "another name" } })
      assert_flash_success
      assert_equal(2, APIKey.count)
      assert_equal(2, mary.reload.api_keys.length)
      key2 = mary.api_keys.last
      assert_equal("another name", key2.notes)
      assert_redirected_to(action: "index")
      get("index") # It doesn't follow the redirect.
      assert_select("[data-role='edit_api_key']", count: 2)

      # Remove first key.
      delete(:destroy, params: { id: key1.id })
      assert_flash_success
      assert_equal(1, APIKey.count)
      assert_equal(1, mary.reload.api_keys.length)
      key = mary.api_keys.last
      assert_objs_equal(key, key2)
      assert_redirected_to(action: "index")
      get("index") # It doesn't follow the redirect.
      assert_select("[data-role='edit_api_key']", count: 1)
    end

    def test_update_api_key
      key = mary.api_keys.create(notes: "app name")

      # Have Mary edit her own key.
      login("mary")

      # Try to change notes to empty string.
      patch(:update, params: { id: key.id, api_key: { notes: "" } })
      assert_flash_error
      # assert_response(:success) # means failure

      # Change notes correctly.
      patch(:update, params: { id: key.id, api_key: { notes: "new name" } })
      assert_flash_success
      assert_redirected_to(account_api_keys_path)
      assert_equal("new name", key.reload.notes)
    end
  end
end
