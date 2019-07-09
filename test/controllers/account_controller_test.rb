require "test_helper"

class AccountControllerTest < FunctionalTestCase
  def setup
    @request.host = "localhost"
    super
  end

  ##############################################################################

  def test_auth_rolf
    @request.session["return-to"] = "http://localhost/bogus/location"
    post(:login, user: { login: "rolf", password: "testpassword" })
    assert_response("http://localhost/bogus/location")
    assert_flash_text(:runtime_login_success.t)
    assert(@request.session[:user_id],
           "Didn't store user in session after successful login!")
    assert_equal(rolf.id, @request.session[:user_id],
                 "Wrong user stored in session after successful login!")
  end

  def test_signup
    @request.session["return-to"] = "http://localhost/bogus/location"
    num_users = User.count
    post(:signup, new_user: {
           login: "newbob",
           password: "newpassword",
           password_confirmation: "newpassword",
           email: "nathan@collectivesource.com",
           email_confirmation: "nathan@collectivesource.com",
           name: "needs a name!",
           theme: "NULL"
         })
    assert_equal("http://localhost/bogus/location", @response.redirect_url)
    assert_equal(num_users + 1, User.count)
    user = User.last
    assert_equal("newbob", user.login)
    assert_equal("needs a name!", user.name)
    assert_equal("nathan@collectivesource.com", user.email)
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
    post(:signup, new_user: params.except(:password))
    assert_flash_error
    assert_response(:success)
    assert(assigns("new_user").errors[:password].any?)

    # Password doesn't match
    post(:signup, new_user: params.merge(password_confirmation: "wrong"))
    assert_flash_error
    assert_response(:success)
    assert(assigns("new_user").errors[:password].any?)

    # No email
    post(:signup, new_user: params.except(:email))
    assert_flash_error
    assert_response(:success)
    assert(assigns("new_user").errors[:email].any?,
           assigns("new_user").dump_errors)

    # Email doesn't match.
    post(:signup, new_user: params.merge(email_confirmation: "wrong"))
    assert_flash_error
    assert_response(:success)
    assert(assigns("new_user").errors[:email].any?)

    # Make sure correct request would have succeeded!
    post(:signup, new_user: params)
    assert_flash_success
    assert_response(:redirect)
    assert_not_nil(User.find_by_login("newbob"))
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
    post(:signup, new_user: params.merge(theme: ""))
    assert_no_flash
    assert_nil(User.find_by_login("spammer"))
    assert_nil(@request.session["user_id"])
    assert_redirected_to(referrer)

    @request.session["return-to"] = referrer
    post(:signup, new_user: params.merge(theme: "spammer"))
    assert_no_flash
    assert_nil(User.find_by_login("spammer"))
    assert_nil(@request.session["user_id"])
    assert_redirected_to(referrer)
  end

  def test_invalid_login
    post(:login, user: { login: "rolf", password: "not_correct" })
    assert_nil(@request.session["user_id"])
    assert_template("login")

    user = User.create!(
      login: "api",
      email: "foo@bar.com"
    )
    post(:login, user: { login: "api", password: "" })
    assert_nil(@request.session["user_id"])
    assert_template("login")

    user.update(verified: Time.zone.now)
    post(:login, user: { login: "api", password: "" })
    assert_nil(@request.session["user_id"])
    assert_template("login")

    user.change_password("try_this_for_size")
    post(:login, user: { login: "api", password: "try_this_for_size" })
    assert(@request.session["user_id"])
  end

  def test_email_new_password
    get(:email_new_password)
    assert_no_flash

    post(:email_new_password,
         new_user: {
           login: "brandnewuser",
           password: "brandnewpassword",
           password_confirmation: "brandnewpassword",
           name: "brand new name"
         })
    assert_flash_error(
      "email_new_password should flash error if user doesn't already exist"
    )
  end

  # Test autologin feature.
  def test_autologin
    # Make sure test page that requires login fails without autologin cookie.
    get(:test_autologin)
    assert_response(:redirect)

    # Make sure cookie is not set if clear remember_me box in login.
    post(:login,
         user: { login: "rolf", password: "testpassword", remember_me: "" })
    assert(session[:user_id])
    assert(!cookies["mo_user"])

    logout
    get(:test_autologin)
    assert_response(:redirect)

    # Now clear session and try again with remember_me box set.
    post(:login,
         user: { login: "rolf", password: "testpassword", remember_me: "1" })
    assert(session[:user_id])
    assert(cookies["mo_user"])

    # And make sure autologin will pick that cookie up and do its thing.
    logout
    @request.cookies["mo_user"] = cookies["mo_user"]
    get(:test_autologin)
    assert_response(:success)
  end

  def test_normal_verify
    user = User.create!(
      login: "micky",
      password: "mouse",
      password_confirmation: "mouse",
      email: "mm@disney.com"
    )
    assert(user.auth_code.present?)
    assert(user.auth_code.length > 10)

    get(:verify, id: user.id, auth_code: "bogus_code")
    assert_template("reverify")
    assert(!@request.session[:user_id])

    get(:verify, id: user.id, auth_code: user.auth_code)
    assert_template("verify")
    assert(@request.session[:user_id])
    assert_users_equal(user, assigns(:user))
    assert_not_nil(user.reload.verified)

    get(:verify, id: user.id, auth_code: user.auth_code)
    assert_redirected_to(action: :welcome)
    assert(@request.session[:user_id])
    assert_users_equal(user, assigns(:user))

    login("rolf")
    get(:verify, id: user.id, auth_code: user.auth_code)
    assert_redirected_to(action: :login)
    assert(!@request.session[:user_id])
  end

  def test_verify_after_api_create
    user = User.create!(
      login: "micky",
      email: "mm@disney.com"
    )

    get(:verify, id: user.id, auth_code: "bogus_code")
    assert_template("reverify")
    assert(!@request.session[:user_id])

    get(:verify, id: user.id, auth_code: user.auth_code)
    assert_flash_warning
    assert_template("choose_password")
    assert(!@request.session[:user_id])
    assert_users_equal(user, assigns(:user))
    assert_input_value("user_password", "")
    assert_input_value("user_password_confirmation", "")

    post(:verify, id: user.id, auth_code: user.auth_code,
                  user: {})
    assert_flash_error
    assert_template("choose_password")
    assert_input_value("user_password", "")
    assert_input_value("user_password_confirmation", "")

    # Password and confirmation don't match
    post(:verify, id: user.id, auth_code: user.auth_code,
                  user: { password: "mouse", password_confirmation: "moose" })
    assert_flash_error
    assert_template("choose_password")
    assert_input_value("user_password", "mouse")
    assert_input_value("user_password_confirmation", "")

    # Password invalid (too short)
    post(:verify, id: user.id, auth_code: user.auth_code,
                  user: { password: "mo", password_confirmation: "mo" })
    assert_flash_error
    assert_template("choose_password")
    assert_input_value("user_password", "mo")
    assert_input_value("user_password_confirmation", "")

    post(:verify, id: user.id, auth_code: user.auth_code,
                  user: { password: "mouse", password_confirmation: "mouse" })
    assert_template("verify")
    assert(@request.session[:user_id])
    assert_users_equal(user, assigns(:user))
    assert_not_nil(user.reload.verified)
    assert_not_equal("", user.password)

    login("rolf")
    get(:verify, id: user.id, auth_code: user.auth_code)
    assert_redirected_to(action: :login)
    assert(!@request.session[:user_id])
  end

  def test_reverify
    assert_raises(RuntimeError) { post(:reverify) }
  end

  def test_send_verify
    user = User.create!(
      login: "micky",
      email: "mm@disney.com"
    )
    post(:send_verify, id: user.id)
    assert_flash_success
  end

  def test_send_verify_hotmail
    user = User.create!(
      login: "micky",
      email: "mm@hotmail.com"
    )
    post(:send_verify, id: user.id)
    assert_flash_success
  end

  def test_edit_prefs
    # First make sure it can serve the form to start with.
    requires_login(:prefs)
    Language.all.each do |lang|
      assert_select("option[value=#{lang.locale}]", { count: 1 },
                    "#{lang.locale} language option missing")
    end
    assert_input_value(:user_login, "rolf")
    assert_input_value(:user_email, "rolf@collectivesource.com")
    assert_input_value(:user_password, "")
    assert_input_value(:user_password_confirmation, "")
    assert_input_value(:user_thumbnail_maps, "1")
    assert_input_value(:user_view_owner_id, "1")
    assert_input_value(:user_has_images, "")
    assert_input_value(:user_has_specimen, "")
    assert_input_value(:user_lichen, nil)
    assert_input_value(:user_region, "")
    assert_input_value(:user_clade, "")

    # Now change everything.
    params = {
      login: "rolf",
      password: "new_password",
      password_confirmation: "new_password",
      email: "new@email.com",
      email_comments_all: "",
      email_comments_owner: "1",
      email_comments_response: "1",
      email_general_commercial: "1",
      email_general_feature: "1",
      email_general_question: "1",
      email_html: "1",
      email_locations_admin: "1",
      email_locations_all: "",
      email_locations_author: "1",
      email_locations_editor: "",
      email_names_admin: "1",
      email_names_all: "",
      email_names_author: "1",
      email_names_editor: "",
      email_names_reviewer: "1",
      email_observations_all: "",
      email_observations_consensus: "1",
      email_observations_naming: "1",
      hide_authors: :above_species,
      keep_filenames: :keep_but_hide,
      license_id: licenses(:publicdomain).id.to_s,
      layout_count: "100",
      locale: "el",
      location_format: :scientific,
      notes_template: "Collector's #",
      theme: "Agaricus",
      thumbnail_maps: "",
      view_owner_id: "",
      votes_anonymous: :yes,
      has_images: "1",
      has_specimen: "1",
      lichen: "yes",
      region: "California",
      clade: "Ascomycota"
    }

    # Prove that all the values are initialized correctly if reloading form.
    post(:prefs, user: params.merge(password_confirmation: "bogus"))
    assert_flash_error
    assert_response(:success)
    assert_input_value(:user_password, "")
    assert_input_value(:user_password_confirmation, "")
    assert_input_value(:user_email, "new@email.com")
    assert_input_value(:user_email_comments_all, "")
    assert_input_value(:user_email_comments_owner, "1")
    assert_input_value(:user_email_comments_response, "1")
    assert_input_value(:user_email_general_commercial, "1")
    assert_input_value(:user_email_general_feature, "1")
    assert_input_value(:user_email_general_question, "1")
    assert_input_value(:user_email_html, "1")
    assert_input_value(:user_email_locations_admin, "1")
    assert_input_value(:user_email_locations_all, "")
    assert_input_value(:user_email_locations_author, "1")
    assert_input_value(:user_email_locations_editor, "")
    assert_input_value(:user_email_names_admin, "1")
    assert_input_value(:user_email_names_all, "")
    assert_input_value(:user_email_names_author, "1")
    assert_input_value(:user_email_names_editor, "")
    assert_input_value(:user_email_names_reviewer, "1")
    assert_input_value(:user_email_observations_all, "")
    assert_input_value(:user_email_observations_consensus, "1")
    assert_input_value(:user_email_observations_naming, "1")
    assert_input_value(:user_hide_authors, :above_species)
    assert_input_value(:user_keep_filenames, :keep_but_hide)
    assert_input_value(:user_license_id, licenses(:publicdomain).id.to_s)
    assert_input_value(:user_layout_count, "100")
    assert_input_value(:user_locale, "el")
    assert_input_value(:user_location_format, :scientific)
    assert_textarea_value(:user_notes_template, "Collector's #")
    assert_input_value(:user_theme, "Agaricus")
    assert_input_value(:user_thumbnail_maps, "")
    assert_input_value(:user_view_owner_id, "")
    assert_input_value(:user_votes_anonymous, :yes)
    assert_input_value(:user_has_images, "1")
    assert_input_value(:user_has_specimen, "1")
    assert_input_value(:user_lichen, "yes")
    assert_input_value(:user_region, "California")
    assert_input_value(:user_clade, "Ascomycota")

    # Now do it correctly, and make sure changes were made.
    post(:prefs, user: params)
    assert_flash_text(:runtime_prefs_success.t)
    user = rolf.reload
    assert_equal("new@email.com", user.email)
    assert_equal(false, user.email_comments_all)
    assert_equal(true, user.email_comments_owner)
    assert_equal(true, user.email_comments_response)
    assert_equal(true, user.email_general_commercial)
    assert_equal(true, user.email_general_feature)
    assert_equal(true, user.email_general_question)
    assert_equal(true, user.email_html)
    assert_equal(true, user.email_locations_admin)
    assert_equal(false, user.email_locations_all)
    assert_equal(true, user.email_locations_author)
    assert_equal(false, user.email_locations_editor)
    assert_equal(true, user.email_names_admin)
    assert_equal(false, user.email_names_all)
    assert_equal(true, user.email_names_author)
    assert_equal(false, user.email_names_editor)
    assert_equal(true, user.email_names_reviewer)
    assert_equal(false, user.email_observations_all)
    assert_equal(true, user.email_observations_consensus)
    assert_equal(true, user.email_observations_naming)
    assert_equal(:above_species, user.hide_authors)
    assert_equal(:keep_but_hide, user.keep_filenames)
    assert_equal(100, user.layout_count)
    assert_equal(licenses(:publicdomain), user.license)
    assert_equal("el", user.locale)
    assert_equal(:scientific, user.location_format)
    assert_equal("Collector's #", user.notes_template)
    assert_equal("Agaricus", user.theme)
    assert_equal(false, user.thumbnail_maps)
    assert_equal(false, user.view_owner_id)
    assert_equal(:yes, user.votes_anonymous)
    assert_equal("yes", user.content_filter[:has_images])
    assert_equal("yes", user.content_filter[:has_specimen])
    assert_equal("yes", user.content_filter[:lichen])
    assert_equal("California", user.content_filter[:region])
    assert_equal("Ascomycota", user.content_filter[:clade])

    # Prove user cannot pick "Other" as a notes_template heading
    old_notes_template = user.notes_template
    # prior test set the locale to Greece
    # reset locale to get less incomprehensible error messages
    user.locale = "en"
    user.save
    post(:prefs, user: params.merge(notes_template: "Size, Other"))
    assert_flash_error
    assert_equal(old_notes_template, user.reload.notes_template)

    # Prove user cannot have duplicate headings in notes template
    post(:prefs, user: params.merge(notes_template: "Yadda, Yadda"))
    assert_flash_error
    assert_equal(old_notes_template, user.reload.notes_template)

    # Prove login can't already exist.
    post(:prefs, user: params.merge(login: "mary"))
    assert_flash_error
    assert_equal("rolf", user.reload.login)

    # But does work if it's new!
    post(:prefs, user: params.merge(login: "steve"))
    assert_equal("steve", user.reload.login)

    # Prove password was changed correctly somewhere along the line.
    logout
    post(:login, user: { login: "steve", password: "new_password" })
    assert_equal(rolf.id, @request.session["user_id"])
  end

  def test_edit_profile
    # First make sure it can serve the form to start with.
    requires_login(:profile)

    # Now change everything. (Note that this user owns no images, so this tests
    # the bulk copyright_holder updater in the boundary case of no images.)
    params = {
      user: {
        name: "new_name",
        notes: "new_notes",
        place_name: "Burbank, California, USA",
        mailing_address: ""
      }
    }
    post_with_dump(:profile, params)
    assert_flash_text(:runtime_profile_success.t)

    # Make sure changes were made.
    user = rolf.reload
    assert_equal("new_name", user.name)
    assert_equal("new_notes", user.notes)
    assert_equal(locations(:burbank), user.location)
  end

  # Test uploading mugshot for user profile.
  def test_add_mugshot
    # Create image directory and populate with test images.
    setup_image_dirs

    # Open file we want to upload.
    file = Rack::Test::UploadedFile.new(
      "#{::Rails.root}/test/images/sticky.jpg", "image/jpeg"
    )

    # It should create a new image: this is the current number of images.
    num_images = Image.count

    # Post form.
    params = {
      user: {
        name: rolf.name,
        place_name: "",
        notes: "",
        upload_image: file,
        mailing_address: rolf.mailing_address
      },
      copyright_holder: "Someone Else",
      upload: { license_id: licenses(:ccnc25).id },
      date: { copyright_year: "2003" }
    }
    File.stub(:rename, false) do
      login("rolf", "testpassword")
      post_with_dump(:profile, params)
    end
    assert_redirected_to(controller: :observer, action: :show_user, id: rolf.id)
    assert_flash_success

    rolf.reload
    assert_equal(num_images + 1, Image.count)
    assert_equal(Image.last.id, rolf.image_id)
    assert_equal("Someone Else", rolf.image.copyright_holder)
    assert_equal(2003, rolf.image.when.year)
    assert_equal(licenses(:ccnc25), rolf.image.license)
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
      assert(!rolf.reload.send("email_#{type}"))
    end
  end

  def test_api_key_manager
    ApiKey.all.each(&:destroy)
    assert_equal(0, ApiKey.count)

    # Get initial (empty) form.
    requires_login(:api_keys)
    assert_select("a[data-role*=edit_api_key]", count: 0)
    assert_select("a[data-role*=activate_api_key]", count: 0)
    assert_input_value(:key_notes, "")

    # Try to create key with no name.
    login("mary")
    post(:api_keys, commit: :account_api_keys_create_button.l)
    assert_flash_error
    assert_equal(0, ApiKey.count)
    assert_select("a[data-role*=edit_api_key]", count: 0)

    # Create good key.
    post(:api_keys, commit: :account_api_keys_create_button.l,
                    key: { notes: "app name" })
    assert_flash_success
    assert_equal(1, ApiKey.count)
    assert_equal(1, mary.reload.api_keys.length)
    key1 = mary.api_keys.first
    assert_equal("app name", key1.notes)
    assert_select("a[data-role*=edit_api_key]", count: 1)

    # Create another key.
    post(:api_keys, commit: :account_api_keys_create_button.l,
                    key: { notes: "another name" })
    assert_flash_success
    assert_equal(2, ApiKey.count)
    assert_equal(2, mary.reload.api_keys.length)
    key2 = mary.api_keys.last
    assert_equal("another name", key2.notes)
    assert_select("a[data-role*=edit_api_key]", count: 2)

    # Press "remove" without selecting anything.
    post(:api_keys, commit: :account_api_keys_remove_button.l)
    assert_flash_warning
    assert_equal(2, ApiKey.count)
    assert_select("a[data-role*=edit_api_key]", count: 2)

    # Remove first key.
    post(:api_keys, commit: :account_api_keys_remove_button.l,
                    "key_#{key1.id}" => "1")
    assert_flash_success
    assert_equal(1, ApiKey.count)
    assert_equal(1, mary.reload.api_keys.length)
    key = mary.api_keys.last
    assert_objs_equal(key, key2)
    assert_select("a[data-role*=edit_api_key]", count: 1)
  end

  def test_activate_api_key
    key = ApiKey.new
    key.provide_defaults
    key.verified = nil
    key.notes = "Testing"
    key.user = katrina
    key.save
    assert_nil(key.verified)

    get(:activate_api_key, id: 12_345)
    assert_redirected_to(action: :login)
    assert_nil(key.verified)

    login("dick")
    get(:activate_api_key, id: key.id)
    assert_flash_error
    assert_redirected_to(action: :api_keys)
    assert_nil(key.verified)
    flash.clear

    login("katrina")
    get(:api_keys)
    assert_select("a[data-role*=edit_api_key]", count: 1)
    assert_select("a[data-role*=activate_api_key]", count: 1)

    get(:activate_api_key, id: key.id)
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
    get(:edit_api_key, id: key.id)
    assert_response(:redirect)

    # Try to edit another user's key.
    login("dick")
    get(:edit_api_key, id: key.id)
    assert_response(:redirect)

    # Have Mary edit her own key.
    login("mary")
    get(:edit_api_key, id: key.id)
    assert_response(:success)
    assert_input_value(:key_notes, "app name")

    # Cancel form.
    post(:edit_api_key, commit: :CANCEL.l, id: key.id)
    assert_response(:redirect)
    assert_equal("app name", key.reload.notes)

    # Try to change notes to empty string.
    post(:edit_api_key, commit: :UPDATE.l, id: key.id, key: { notes: "" })
    assert_flash_error
    assert_response(:success) # means failure

    # Change notes correctly.
    post(:edit_api_key,
         commit: :UPDATE.l, id: key.id, key: { notes: "new name" })
    assert_flash_success
    assert_redirected_to(action: :api_keys)
    assert_equal("new name", key.reload.notes)
  end
end
