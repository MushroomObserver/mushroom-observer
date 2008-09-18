require File.dirname(__FILE__) + '/../test_helper'
require 'account_controller'

# Raise errors beyond the default web-based presentation
class AccountController; def rescue_action(e) raise e end; end

class AccountControllerTest < Test::Unit::TestCase

  fixtures :users
  fixtures :images
  fixtures :licenses
  fixtures :locations

  def setup
    @controller = AccountController.new
    @request, @response = ActionController::TestRequest.new, ActionController::TestResponse.new
    @request.host = "localhost"
  end

  def teardown
    if File.exists?(IMG_DIR)
      FileUtils.rm_rf(IMG_DIR)
    end
  end

  def test_auth_rolf
    @request.session['return-to'] = "http://localhost/bogus/location"

    post :login, "user_login" => "rolf", "user_password" => "testpassword"
    assert(@response.has_session_object?(:user_id))

    assert_equal @rolf.id, @response.session[:user_id]

    assert_equal("http://localhost/bogus/location", @response.redirect_url)
  end

  def test_signup
    @request.session['return-to'] = "http://localhost/bogus/location"

    post :signup, "new_user" => { "login" => "newbob", "password" => "newpassword", "password_confirmation" => "newpassword",
                              "email" => "nathan@collectivesource.com", "mailing_address" => "", "theme" => "NULL", "notes" => "" }
    assert(@response.has_session_object?(:user_id))

    assert_equal("http://localhost/bogus/location", @response.redirect_url)
  end

  def test_bad_signup
    @request.session['return-to'] = "http://localhost/bogus/location"

    # Password doesn't match
    post :signup, "new_user" => { "login" => "newbob", "password" => "newpassword", "password_confirmation" => "wrong",
      "mailing_address" => "", "theme" => "NULL", "notes" => "" }
    assert(@response.template_objects["new_user"].errors.invalid?(:password))

    # No email
    post :signup, "new_user" => { "login" => "yo", "password" => "newpassword", "password_confirmation" => "newpassword",
      "mailing_address" => "", "theme" => "NULL", "notes" => "" }
    assert(@response.template_objects["new_user"].errors.invalid?(:login))

    # Bad password and no email
    post :signup, "new_user" => { "login" => "yo", "password" => "newpassword", "password_confirmation" => "wrong",
      "mailing_address" => "", "theme" => "NULL", "notes" => "" }
    assert(@response.template_objects["new_user"].errors.invalid?(:password))
    assert(@response.template_objects["new_user"].errors.invalid?(:login))
  end

  def test_signup_theme_errors
    @request.session['return-to'] = "http://localhost/bogus/location"

    post :signup, "new_user" => { "login" => "spammer", "password" => "spammer", "password_confirmation" => "spammer",
                              "email" => "spam@spam.spam", "mailing_address" => "", "theme" => "", "notes" => "" }
    assert(!@response.has_session_object?("user"))

    assert_equal("http://localhost/bogus/location", @response.redirect_url)

    post :signup, "new_user" => { "login" => "spammer", "password" => "spammer", "password_confirmation" => "spammer",
                              "email" => "spam@spam.spam", "mailing_address" => "", "theme" => "spammer", "notes" => "" }
    assert(!@response.has_session_object?("user"))
    assert_redirected_to(:controller => "account", :action => "welcome")
  end

  def test_invalid_login
    post :login, "user_login" => "rolf", "user_password" => "not_correct"

    assert(!@response.has_session_object?("user"))

    assert(@response.has_template_object?("login"))
  end

#   def test_login_logoff
#
#     post :login, "user_login" => "rolf", "user_password" => "testpassword"
#     assert(@response.has_session_object?("user"))
#
#     get :logout_user
#     assert(!@response.has_session_object?("user"))
#
#   end

  # Test autologin feature.
  def test_autologin
    #
    # First make sure test page that requires login fails without autologin cookie.
    get :test_autologin
    assert_response :redirect
    #
    # Make sure cookie is not set if clear remember_me box in login.
    post :login, {
      "user_login"    => "rolf",
      "user_password" => "testpassword",
      :user => { :remember_me => "" }
    }
    assert session[:user_id]
    assert !cookies[:mo_user]
    session[:user_id] = nil
    get :test_autologin
    assert_response :redirect
    #
    # Now clear session and try again with remember_me box set.
    post :login, {
      "user_login"    => "rolf",
      "user_password" => "testpassword",
      :user => { :remember_me => "1" }
    }
    assert session[:user_id]
    assert cookies['mo_user']
    #
    # And make sure autlogin will pick that cookie up and do its thing.
    session[:user_id] = nil
    @request.cookies['mo_user'] = cookies['mo_user']
    get :test_autologin
    assert_response :success
  end

  def test_edit_prefs
    # First make sure it can serve the form to start with.
    requires_login(:prefs)
    # Now change everything.
    params = {
      :user => {
        :login             => "new_login",
        :email             => "new_email",
        :theme             => "Agaricus",
        :notes             => "",
        :mailing_address   => "",
        :license_id        => "1",
        :rows              => "10",
        :columns           => "10",
        :alternate_rows    => "",
        :alternate_columns => "",
        :vertical_layout   => "",
        :feature_email     => "",
        :comment_email     => "",
        :commercial_email  => "",
        :question_email    => "",
        :html_email        => "",
      }
    }
    post_with_dump(:prefs, params)
    assert_equal("Preferences updated.", flash[:notice])
    # Make sure changes were made.
    user = @rolf .reload
    assert_equal("new_login", user.login)
    assert_equal("new_email", user.email)
    assert_equal("Agaricus", user.theme)
    assert_equal(@ccnc25, user.license)
    assert_equal(10, user.rows)
    assert_equal(10, user.columns)
    assert_equal(false, user.alternate_rows)
    assert_equal(false, user.alternate_columns)
    assert_equal(false, user.vertical_layout)
    assert_equal(false, user.feature_email)
    assert_equal(false, user.comment_email)
    assert_equal(false, user.commercial_email)
    assert_equal(false, user.question_email)
    assert_equal(false, user.html_email)
  end

  def test_edit_prefs_login_already_exists
    params = {
      :user => {
        :login => "mary",
        :email => "email", # (must be defined or will barf)
      }
    }
    post_requires_login(:prefs, params)
  end

  def test_edit_profile
    # First make sure it can serve the form to start with.
    requires_login(:profile)
    # Now change everything.
    params = {
      :user => {
        :name       => "new_name",
        :notes      => "new_notes",
        :place_name => "Burbank, Los Angeles Co., California, USA",
      }
    }
    post_with_dump(:profile, params)
    assert_equal("Profile updated.", flash[:notice])
    # Make sure changes were made.
    user = @rolf.reload
    assert_equal("new_name", user.name)
    assert_equal("new_notes", user.notes)
    assert_equal(@burbank, user.location)
  end

  # Test uploading mugshot for user profile.
  def test_add_mugshot
    # Create image directory and populate with test images.
    FileUtils.cp_r(IMG_DIR.gsub(/test_images$/, 'setup_images'), IMG_DIR)
    # Open file we want to upload.
    file = FilePlus.new("test/fixtures/images/sticky.jpg")
    file.content_type = 'image/jpeg'
    # It should create a new image: this is the ID it should use.
    new_image_id = Image.find(:all).last.id + 1
    # Post form.
    params = {
      :user => {
        :upload_image => file,
        :name         => @rolf.name,
        :mailing_address => @rolf.mailing_address,
      },
      :date => { :copyright_year => "2003" },
      :upload => { :license_id => @ccnc25.id },
      :copyright_holder => "Someone Else",
    }
    post_requires_login(:profile, params, false)
    # assert_redirected_to(:controller => "account", :action => "welcome")
    @rolf.reload
    assert_equal(new_image_id, @rolf.image_id)
    assert_equal("Rolf Singer", @rolf.image.title)
    assert_equal("Someone Else", @rolf.image.copyright_holder)
    assert_equal(2003, @rolf.image.when.year)
    assert_equal(@ccnc25, @rolf.image.license)
  end
end
