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

    # No-JS fallback. The "+ Add Key" button on the index page is a
    # link to this route; with JS, Bootstrap collapse intercepts the
    # click. Without JS, navigation succeeds and lands here.
    def test_new_renders_standalone_create_form
      login("mary")
      get(:new)

      assert_response(:success)
      # Renders the standalone Phlex Form view (notes input + submit).
      assert_select("input[name='api_key[notes]']")
      assert_select("input[type='submit']")
      # Posts to the same `create` action as the inline form.
      assert_select("form[action='#{account_api_keys_path}']")
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

    # The turbo_stream branches in create/update/destroy/activate go
    # through `render_update_table_and_flash`, which emits two
    # `turbo_stream` actions — the table replace and the page-flash
    # update. The legacy ERB partial these replaced (`_update_table_and_flash`)
    # is gone in #4503, so cover the Ruby paths explicitly.
    def test_create_via_turbo_stream
      login("mary")

      post(:create,
           params: { api_key: { notes: "via turbo" } },
           format: :turbo_stream)

      assert_response(:success)
      assert_select(
        "turbo-stream[action='replace'][target='account_api_keys_table']"
      )
      assert_select("turbo-stream[action='update'][target='page_flash']")
      assert(mary.reload.api_keys.any? { |k| k.notes == "via turbo" })
    end

    def test_update_via_turbo_stream
      key = mary.api_keys.create(notes: "before")
      login("mary")

      patch(:update,
            params: { id: key.id, api_key: { notes: "after" } },
            format: :turbo_stream)

      assert_response(:success)
      assert_select(
        "turbo-stream[action='replace'][target='account_api_keys_table']"
      )
      assert_equal("after", key.reload.notes)
    end

    def test_destroy_via_turbo_stream
      key = mary.api_keys.create(notes: "doomed")
      login("mary")

      delete(:destroy, params: { id: key.id }, format: :turbo_stream)

      assert_response(:success)
      assert_select(
        "turbo-stream[action='replace'][target='account_api_keys_table']"
      )
      assert_select("turbo-stream[action='update'][target='page_flash']")
      assert_nil(APIKey.find_by(id: key.id))
    end

    # `activate` flips an unverified key's `verified` timestamp and
    # responds with the same two `turbo_stream` actions.
    def test_activate_via_turbo_stream
      key = APIKey.new(user_id: mary.id, notes: "unverified")
      key.save!
      assert_nil(key.verified)
      login("mary")

      put(:activate, params: { id: key.id }, format: :turbo_stream)

      assert_response(:success)
      assert_select(
        "turbo-stream[action='replace'][target='account_api_keys_table']"
      )
      assert_not_nil(key.reload.verified)
    end

    def test_activate_via_html_redirects
      key = APIKey.new(user_id: mary.id, notes: "unverified")
      key.save!
      login("mary")

      put(:activate, params: { id: key.id })

      assert_redirected_to(account_api_keys_path)
      assert_not_nil(key.reload.verified)
    end
  end
end
