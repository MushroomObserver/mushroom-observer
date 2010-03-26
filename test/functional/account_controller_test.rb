require File.dirname(__FILE__) + '/../boot'

class AccountControllerTest < FunctionalTestCase

  def setup
    @request.host = "localhost"
  end

################################################################################

  def test_auth_rolf
    @request.session['return-to'] = "http://localhost/bogus/location"
    post(:login, "user_login" => "rolf", "user_password" => "testpassword")
    assert_response("http://localhost/bogus/location")
    assert_flash(:runtime_login_success.t)
    assert(@response.has_session_object?(:user_id),
      "Didn't store user in session after successful login!")
    assert_equal(@rolf.id, @response.session[:user_id],
      "Wrong user stored in session after successful login!")
  end

  def test_signup
    @request.session['return-to'] = "http://localhost/bogus/location"
    num_users = User.count
    post(:signup, "new_user" => {
      "login"    => "newbob",
      "password" => "newpassword",
      "password_confirmation" => "newpassword",
      "email"    => "nathan@collectivesource.com",
      "name"     => "needs a name!",
      "theme"    => "NULL"
    })
    assert_equal("http://localhost/bogus/location", @response.redirect_url)
    assert_equal(num_users+1, User.count)
    user = User.last
    assert_equal('newbob', user.login)
    assert_equal('needs a name!', user.name)
    assert_equal('nathan@collectivesource.com', user.email)
    assert_equal(nil, user.verified)
    assert_equal(false, user.admin)
    assert_equal(true, user.created_here)

    # Make sure user groups are updated correctly.
    assert(UserGroup.all_users.users.include?(user))
    assert(group = UserGroup.one_user(user))
    assert_user_list_equal([user], group.users)
  end

  def test_bad_signup
    @request.session['return-to'] = "http://localhost/bogus/location"

    # Password doesn't match
    post(:signup, :new_user => {
      :login => "newbob",
      :password => "newpassword",
      :password_confirmation => "wrong",
      :mailing_address => "",
      :theme => "NULL",
      :notes => ""
    })
    assert(@response.template_objects["new_user"].errors.invalid?(:password))

    # No email
    post(:signup, :new_user => {
      :login => "yo",
      :password => "newpassword",
      :password_confirmation => "newpassword",
      :mailing_address => "",
      :theme => "NULL",
      :notes => ""
    })
    assert(@response.template_objects["new_user"].errors.invalid?(:login))

    # Bad password and no email
    post(:signup, :new_user => {
      :login => "yo",
      :password => "newpassword",
      :password_confirmation => "wrong",
      :mailing_address => "",
      :theme => "NULL",
      :notes => ""
    })
    assert(@response.template_objects["new_user"].errors.invalid?(:password))
    assert(@response.template_objects["new_user"].errors.invalid?(:login))
  end

  def test_signup_theme_errors
    @request.session['return-to'] = "http://localhost/bogus/location"

    post(:signup, :new_user => {
      :login => "spammer",
      :password => "spammer",
      :password_confirmation => "spammer",
      :email => "spam@spam.spam",
      :mailing_address => "",
      :theme => "",
      :notes => ""
    })
    assert(!@response.has_session_object?("user"))

    # Disabled denied email in above case...
    # assert_equal("http://localhost/bogus/location", @response.redirect_url)

    post(:signup, :new_user => {
      :login => "spammer",
      :password => "spammer",
      :password_confirmation => "spammer",
      :email => "spam@spam.spam",
      :mailing_address => "",
      :theme => "spammer",
      :notes => ""
    })
    assert(!@response.has_session_object?("user"))
    assert_response(:action => "welcome")
  end

  def test_invalid_login
    post(:login, :user_login => "rolf", :user_password => "not_correct")
    assert(!@response.has_session_object?("user"))
    assert(@response.has_template_object?("login"))
  end

  # Test autologin feature.
  def test_autologin

    # First make sure test page that requires login fails without autologin cookie.
    get(:test_autologin)
    assert_response(:redirect)

    # Make sure cookie is not set if clear remember_me box in login.
    post(:login,
      :user_login    => "rolf",
      :user_password => "testpassword",
      :user => { :remember_me => "" }
    )
    assert(session[:user_id])
    assert(!cookies[:mo_user])

    logout
    get(:test_autologin)
    assert_response(:redirect)

    # Now clear session and try again with remember_me box set.
    post(:login,
      :user_login    => "rolf",
      :user_password => "testpassword",
      :user => { :remember_me => "1" }
    )
    assert(session[:user_id])
    assert(cookies['mo_user'])

    # And make sure autlogin will pick that cookie up and do its thing.
    logout
    @request.cookies['mo_user'] = cookies['mo_user']
    get(:test_autologin)
    assert_response(:success)
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
        :email_comments_owner         => "1",
        :email_comments_response      => "1",
        :email_comments_all           => "",
        :email_observations_consensus => "1",
        :email_observations_naming    => "1",
        :email_observations_all       => "",
        :email_names_admin            => "1",
        :email_names_author           => "1",
        :email_names_editor           => "",
        :email_names_reviewer         => "1",
        :email_names_all              => "",
        :email_locations_admin        => "1",
        :email_locations_author       => "1",
        :email_locations_editor       => "",
        :email_locations_all          => "",
        :email_general_feature        => "1",
        :email_general_commercial     => "1",
        :email_general_question       => "1",
        :email_html                   => "1",
      }
    }
    post_with_dump(:prefs, params)
    assert_flash(:runtime_prefs_success.t)

    # Make sure changes were made.
    user = @rolf.reload
    assert_equal("new_login",  user.login)
    assert_equal("new_email",  user.email)
    assert_equal("Agaricus",   user.theme)
    assert_equal(licenses(:ccnc25),      user.license)
    assert_equal(10,           user.rows)
    assert_equal(10,           user.columns)
    assert_equal(false,        user.alternate_rows)
    assert_equal(false,        user.alternate_columns)
    assert_equal(false,        user.vertical_layout)
    assert_equal(true,         user.email_comments_owner)
    assert_equal(true,         user.email_comments_response)
    assert_equal(false,        user.email_comments_all)
    assert_equal(true,         user.email_observations_consensus)
    assert_equal(true,         user.email_observations_naming)
    assert_equal(false,        user.email_observations_all)
    assert_equal(true,         user.email_names_admin)
    assert_equal(true,         user.email_names_author)
    assert_equal(false,        user.email_names_editor)
    assert_equal(true,         user.email_names_reviewer)
    assert_equal(false,        user.email_names_all)
    assert_equal(true,         user.email_locations_admin)
    assert_equal(true,         user.email_locations_author)
    assert_equal(false,        user.email_locations_editor)
    assert_equal(false,        user.email_locations_all)
    assert_equal(true,         user.email_general_feature)
    assert_equal(true,         user.email_general_commercial)
    assert_equal(true,         user.email_general_question)
    assert_equal(true,         user.email_html)
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
        :mailing_address => ""
      }
    }
    post_with_dump(:profile, params)
    assert_flash(:runtime_profile_success.t)

    # Make sure changes were made.
    user = @rolf.reload
    assert_equal("new_name", user.name)
    assert_equal("new_notes", user.notes)
    assert_equal(locations(:burbank), user.location)
  end

  # Test uploading mugshot for user profile.
  def test_add_mugshot

    # Create image directory and populate with test images.
    setup_image_dirs

    # Open file we want to upload.
    file = FilePlus.new("#{RAILS_ROOT}/test/fixtures/images/sticky.jpg")
    file.content_type = 'image/jpeg'

    # It should create a new image: this is the current number of images.
    num_images = Image.count

    # Post form.
    params = {
      :user => {
        :name        => @rolf.name,
        :place_name   => '',
        :notes         => '',
        :upload_image   => file,
        :mailing_address => @rolf.mailing_address,
      },
      :copyright_holder => 'Someone Else',
      :upload => { :license_id => licenses(:ccnc25).id },
      :date => { :copyright_year => "2003" },
    }
    post_requires_login(:profile, params)
    assert_response(:controller => :observer, :action => :show_user, :id => 1)
    assert_flash_success

    @rolf.reload
    assert_equal(num_images+1, Image.count)
    assert_equal(Image.last.id, @rolf.image_id)
    assert_equal("Someone Else", @rolf.image.copyright_holder)
    assert_equal(2003, @rolf.image.when.year)
    assert_equal(licenses(:ccnc25), @rolf.image.license)
  end

  def test_no_email_hooks
    for type in [
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
      :general_question,
    ]
      assert_request(
        :action        => "no_email_#{type}",
        :params        => { :id => @rolf.id },
        :require_login => true,
        :require_user  => :index,
        :result        => 'no_email'
      )
      assert(!@rolf.reload.send("email_#{type}"))
    end
  end

  def test_flash_errors
    # First make sure app is working correctly in "live" mode.
    get(:test_flash)
    assert_flash(nil)
    flash[:rendered_notice] = nil

    get_without_clearing_flash(:test_flash, :error => 'error one')
    assert_flash('error one')
    flash[:rendered_notice] = nil

    get_without_clearing_flash(:test_flash, :error => 'error two')
    assert_flash('error two')
    flash[:rendered_notice] = nil

    get_without_clearing_flash(:test_flash, :error => 'error three', :redirect => 1)
    assert_flash('error three')
    flash[:rendered_notice] = nil

    get_without_clearing_flash(:test_flash, :error => 'error four', :redirect => 1)
    assert_flash('error three<br/>error four')
    flash[:rendered_notice] = nil

    get_without_clearing_flash(:test_flash, :error => 'error five')
    assert_flash('error three<br/>error four<br/>error five')
    flash[:rendered_notice] = nil

    get_without_clearing_flash(:test_flash, :redirect => 1, :error => 'dont lose me!')
    get_without_clearing_flash(:test_flash, :redirect => 1)
    get_without_clearing_flash(:test_flash)
    assert_flash('dont lose me!')

    # Now make sure our test suite is clearing out the flash automatically
    # between requests like it should. 
    get(:test_flash, :error => 'tweedle')
    assert_flash('tweedle')

    get(:test_flash, :error => 'dee')
    assert_flash('dee')

    get(:test_flash, :error => 'dum', :redirect => 1)
    assert_flash('dum')

    get(:test_flash, :error => 'jabber', :redirect => 1)
    assert_flash('jabber')

    get(:test_flash, :error => 'wocky')
    get(:test_flash)
    assert_flash(nil)

    get(:test_flash, :error => 'and others', :redirect => 1)
    get(:test_flash, :redirect => 1)
    assert_flash(nil)
  end
end
