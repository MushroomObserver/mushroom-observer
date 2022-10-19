# frozen_string_literal: true

require("test_helper")

# Test user AccountControllerTest
# signup, verification, prefs, profile, api
class AccountControllerTest < FunctionalTestCase
  def setup
    @request.host = "localhost"
    super
  end

  ##############################################################################

  def test_signup
    @request.session["return-to"] = "http://localhost/bogus/location"
    num_users = User.count
    post(:create, params: { new_user: {
           login: "newbob",
           password: "newpassword",
           password_confirmation: "newpassword",
           email: "webmaster@mushroomobserver.org",
           email_confirmation: "webmaster@mushroomobserver.org",
           name: "needs a name!",
           theme: "NULL"
         } })
    assert_equal("http://localhost/bogus/location", @response.redirect_url)
    assert_equal(num_users + 1, User.count)
    user = User.last
    assert_equal("newbob", user.login)
    assert_equal("needs a name!", user.name)
    assert_equal("webmaster@mushroomobserver.org", user.email)
    assert_nil(user.verified)
    assert_equal(false, user.admin)

    # Make sure user groups are updated correctly.
    assert(UserGroup.all_users.users.include?(user))
    assert(group = UserGroup.one_user(user))
    assert_user_list_equal([user], group.users)
  end

  def test_bad_signup
    @request.session["return-to"] = "http://localhost/bogus/location"

    params = {
      login: "newbob",
      password: "topsykritt",
      password_confirmation: "topsykritt",
      email: "blah@somewhere.org",
      email_confirmation: "blah@somewhere.org",
      mailing_address: "",
      theme: "NULL",
      notes: ""
    }

    # Missing password.
    post(:create, params: { new_user: params.except(:password) })
    assert_flash_error
    assert_response(:success)
    assert(assigns("new_user").errors[:password].any?)

    # Password doesn't match
    post(:create,
         params: { new_user: params.merge(password_confirmation: "wrong") })
    assert_flash_error
    assert_response(:success)
    assert(assigns("new_user").errors[:password].any?)

    # No email
    post(:create, params: { new_user: params.except(:email) })
    assert_flash_error
    assert_response(:success)
    assert(assigns("new_user").errors[:email].any?,
           assigns("new_user").dump_errors)

    # Email doesn't match.
    post(:create,
         params: { new_user: params.merge(email_confirmation: "wrong") })
    assert_flash_error
    assert_response(:success)
    assert(assigns("new_user").errors[:email].any?)

    # Make sure correct request would have succeeded!
    post(:create, params: { new_user: params })
    assert_flash_success
    assert_response(:redirect)
    assert_not_nil(User.find_by(login: "newbob"))
  end

  def test_signup_theme_errors
    referrer = "http://localhost/bogus/location"

    params = {
      login: "spammer",
      password: "spammer",
      password_confirmation: "spammer",
      email: "spam@spam.spam",
      mailing_address: "",
      notes: ""
    }

    @request.session["return-to"] = referrer
    post(:create, params: { new_user: params.merge(theme: "") })
    assert_no_flash
    assert_nil(User.find_by(login: "spammer"))
    assert_nil(@request.session["user_id"])
    assert_redirected_to(referrer)

    @request.session["return-to"] = referrer
    post(:create, params: { new_user: params.merge(theme: "spammer") })
    assert_no_flash
    assert_nil(User.find_by(login: "spammer"))
    assert_nil(@request.session["user_id"])
    assert_redirected_to(referrer)
  end

  def test_anon_user_signup
    get(:new)

    assert_response(:success)
    assert_head_title(:signup_title.l)
  end

  def test_anon_user_welcome
    get(:welcome)

    assert_response(:success)
    assert_head_title(:welcome_no_user_title.l)
  end

  def test_block_known_evil_signups
    params = {
      login: "newbob",
      password: "topsykritt",
      password_confirmation: "topsykritt",
      email: "blah@somewhere.org",
      email_confirmation: "blah@somewhere.org",
      mailing_address: "",
      theme: "NULL",
      notes: ""
    }
    html_client_error = 400..499

    post(:create, params: { new_user: params.merge(login: "xUplilla") })
    assert(html_client_error.include?(response.status),
           "Signup response should be 4xx")

    post(:create, params: { new_user: params.merge(email: "x@namnerbca.com") })
    assert(html_client_error.include?(response.status),
           "Signup response should be 4xx")

    post(:create,
         params: {
           new_user: params.merge(email: "b.l.izk.o.ya.n201.7@gmail.com\r\n")
         })
    assert(html_client_error.include?(response.status),
           "Signup response should be 4xx")
  end

  def test_no_email_hooks
    [
      :comments_owner,
      :comments_response,
      :comments_all,
      :observations_consensus,
      :observations_naming,
      :observations_all,
      :names_author,
      :names_editor,
      :names_reviewer,
      :names_all,
      :locations_author,
      :locations_editor,
      :locations_all,
      :general_feature,
      :general_commercial,
      :general_question
    ].each do |type|
      assert_request(
        action: "no_email_#{type}",
        params: { id: rolf.id },
        require_login: true,
        require_user: :index,
        result: "no_email"
      )
      assert_not(rolf.reload.send("email_#{type}"))
    end
  end

  def test_api_key_manager
    APIKey.all.each(&:destroy)
    assert_equal(0, APIKey.count)

    # Get initial (empty) form.
    requires_login(:api_keys)
    assert_select("a[data-role*=edit_api_key]", count: 0)
    assert_select("a[data-role*=activate_api_key]", count: 0)
    assert_input_value(:key_notes, "")

    # Try to create key with no name.
    login("mary")
    post(:api_keys, params: { commit: :account_api_keys_create_button.l })
    assert_flash_error
    assert_equal(0, APIKey.count)
    assert_select("a[data-role*=edit_api_key]", count: 0)

    # Create good key.
    post(:api_keys,
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
    post(:api_keys,
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
    post(:api_keys, params: { commit: :account_api_keys_remove_button.l })
    assert_flash_warning
    assert_equal(2, APIKey.count)
    assert_select("a[data-role*=edit_api_key]", count: 2)

    # Remove first key.
    post(:api_keys,
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

    get(:activate_api_key, params: { id: 12_345 })
    assert_redirected_to(new_account_login_path)
    assert_nil(key.verified)

    login("dick")
    get(:activate_api_key, params: { id: key.id })
    assert_flash_error
    assert_redirected_to(action: :api_keys)
    assert_nil(key.verified)
    flash.clear

    login("katrina")
    get(:api_keys)
    assert_select("a[data-role*=edit_api_key]", count: 1)
    assert_select("a[data-role*=activate_api_key]", count: 1)

    get(:activate_api_key, params: { id: key.id })
    assert_flash_success
    assert_redirected_to(action: :api_keys)
    key.reload
    assert_not_nil(key.verified)

    get(:api_keys)
    assert_select("a[data-role*=edit_api_key]", count: 1)
    assert_select("a[data-role*=activate_api_key]", count: 0)
  end

  def test_edit_api_key
    key = mary.api_keys.create(notes: "app name")

    # Try without logging in.
    get(:edit_api_key, params: { id: key.id })
    assert_response(:redirect)

    # Try to edit another user's key.
    login("dick")
    get(:edit_api_key, params: { id: key.id })
    assert_response(:redirect)

    # Have Mary edit her own key.
    login("mary")
    get(:edit_api_key, params: { id: key.id })
    assert_response(:success)
    assert_input_value(:key_notes, "app name")

    # Cancel form.
    post(:edit_api_key, params: { commit: :CANCEL.l, id: key.id })
    assert_response(:redirect)
    assert_equal("app name", key.reload.notes)

    # Try to change notes to empty string.
    post(:edit_api_key,
         params: { commit: :UPDATE.l, id: key.id, key: { notes: "" } })
    assert_flash_error
    assert_response(:success) # means failure

    # Change notes correctly.
    post(:edit_api_key,
         params: { commit: :UPDATE.l, id: key.id, key: { notes: "new name" } })
    assert_flash_success
    assert_redirected_to(action: :api_keys)
    assert_equal("new name", key.reload.notes)
  end
end
