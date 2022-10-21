# frozen_string_literal: true

require("test_helper")

# tests of API Keys controller
class Account::APIKeysControllerTest < FunctionalTestCase
  def test_api_key_manager
    APIKey.all.each(&:destroy)
    assert_equal(0, APIKey.count)

    # Get initial (empty) form.
    requires_login("index")
    assert_select("a[data-role*=edit_api_key]", count: 0)
    assert_select("a[data-role*=activate_api_key]", count: 0)
    assert_input_value(:key_notes, "")

    # Try to create key with no name.
    login("mary")
    post(:create, params: { commit: :account_api_keys_create_button.l })
    assert_flash_error
    assert_equal(0, APIKey.count)
    assert_select("a[data-role*=edit_api_key]", count: 0)

    # Create good key.
    post(:create,
         params: {
           commit: :account_api_keys_create_button.l,
           key: { notes: "app name" }
         })
    assert_flash_success
    assert_equal(1, APIKey.count)
    assert_equal(1, mary.reload.api_keys.length)
    key1 = mary.api_keys.first
    assert_equal("app name", key1.notes)
    assert_select("a[data-role*=edit_api_key]", count: 1)

    # Create another key.
    post(:create,
         params: {
           commit: :account_api_keys_create_button.l,
           key: { notes: "another name" }
         })
    assert_flash_success
    assert_equal(2, APIKey.count)
    assert_equal(2, mary.reload.api_keys.length)
    key2 = mary.api_keys.last
    assert_equal("another name", key2.notes)
    assert_select("a[data-role*=edit_api_key]", count: 2)

    # Press "remove" without selecting anything.
    post(:remove, params: { commit: :account_api_keys_remove_button.l })
    assert_flash_warning
    assert_equal(2, APIKey.count)
    assert_select("a[data-role*=edit_api_key]", count: 2)

    # Remove first key.
    post(:remove,
         params: {
           commit: :account_api_keys_remove_button.l,
           "key_#{key1.id}" => "1"
         })
    assert_flash_success
    assert_equal(1, APIKey.count)
    assert_equal(1, mary.reload.api_keys.length)
    key = mary.api_keys.last
    assert_objs_equal(key, key2)
    assert_select("a[data-role*=edit_api_key]", count: 1)
  end

  def test_activate_api_key
    key = APIKey.new
    key.provide_defaults
    key.verified = nil
    key.notes = "Testing"
    key.user = katrina
    key.save
    assert_nil(key.verified)

    get(:activate, params: { id: 12_345 })
    assert_redirected_to(new_account_login_path)
    assert_nil(key.verified)

    login("dick")
    get(:activate, params: { id: key.id })
    assert_flash_error
    assert_redirected_to(account_api_keys_path)
    assert_nil(key.verified)
    flash.clear

    login("katrina")
    get(:index)
    assert_select("a[data-role*=edit_api_key]", count: 1)
    assert_select("a[data-role*=activate_api_key]", count: 1)

    get(:activate, params: { id: key.id })
    assert_flash_success
    assert_redirected_to(account_api_keys_path)
    key.reload
    assert_not_nil(key.verified)

    get(:index)
    assert_select("a[data-role*=edit_api_key]", count: 1)
    assert_select("a[data-role*=activate_api_key]", count: 0)
  end

  def test_edit_api_key
    key = mary.api_keys.create(notes: "app name")

    # Try without logging in.
    get(:edit, params: { id: key.id })
    assert_response(:redirect)

    # Try to edit another user's key.
    login("dick")
    get(:edit, params: { id: key.id })
    assert_response(:redirect)

    # Have Mary edit her own key.
    login("mary")
    get(:edit, params: { id: key.id })
    assert_response(:success)
    assert_input_value(:key_notes, "app name")

    # Cancel form.
    patch(:update, params: { commit: :CANCEL.l, id: key.id })
    assert_redirected_to(account_api_keys_path)
    assert_equal("app name", key.reload.notes)

    # Try to change notes to empty string.
    patch(:update,
          params: { commit: :UPDATE.l, id: key.id, key: { notes: "" } })
    assert_flash_error
    assert_response(:success) # means failure

    # Change notes correctly.
    patch(:update,
          params: { commit: :UPDATE.l, id: key.id, key: { notes: "new name" } })
    assert_flash_success
    assert_redirected_to(account_api_keys_path)
    assert_equal("new name", key.reload.notes)
  end
end
