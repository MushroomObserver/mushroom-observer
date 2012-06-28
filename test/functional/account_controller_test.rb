# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot')

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

    # Make sure "beta" languages are present.
    for lang in Language.all
      assert_select("option[value=#{lang.locale}]")
    end

    # Now change everything.
    params = {
      :user => {
        :alternate_columns             => '',
        :alternate_rows                => '',
        :columns                       => '10',
        :email                         => 'new_email',
        :email_comments_all            => '',
        :email_comments_owner          => '1',
        :email_comments_response       => '1',
        :email_general_commercial      => '1',
        :email_general_feature         => '1',
        :email_general_question        => '1',
        :email_html                    => '1',
        :email_locations_admin         => '1',
        :email_locations_all           => '',
        :email_locations_author        => '1',
        :email_locations_editor        => '',
        :email_names_admin             => '1',
        :email_names_all               => '',
        :email_names_author            => '1',
        :email_names_editor            => '',
        :email_names_reviewer          => '1',
        :email_observations_all        => '',
        :email_observations_consensus  => '1',
        :email_observations_naming     => '1',
        :hide_authors                  => 'above_species',
        :image_size                    => 'small',
        :keep_filenames                => '',
        :license_id                    => '1',
        :locale                        => 'el-GR',
        :location_format               => 'scientific',
        :login                         => 'new_login',
        :rows                          => '10',
        :theme                         => 'Agaricus',
        :thumbnail_maps                => '',
        :thumbnail_size                => 'small',
        :vertical_layout               => '',
        :votes_anonymous               => 'yes',
      }
    }
    post_with_dump(:prefs, params)
    assert_flash(:runtime_prefs_success.t)

    # Make sure changes were made.
    user = @rolf.reload
    assert_equal(false,       user.alternate_columns)
    assert_equal(false,       user.alternate_rows)
    assert_equal(10,          user.columns)
    assert_equal('new_email', user.email)
    assert_equal(false,       user.email_comments_all)
    assert_equal(true,        user.email_comments_owner)
    assert_equal(true,        user.email_comments_response)
    assert_equal(true,        user.email_general_commercial)
    assert_equal(true,        user.email_general_feature)
    assert_equal(true,        user.email_general_question)
    assert_equal(true,        user.email_html)
    assert_equal(true,        user.email_locations_admin)
    assert_equal(false,       user.email_locations_all)
    assert_equal(true,        user.email_locations_author)
    assert_equal(false,       user.email_locations_editor)
    assert_equal(true,        user.email_names_admin)
    assert_equal(false,       user.email_names_all)
    assert_equal(true,        user.email_names_author)
    assert_equal(false,       user.email_names_editor)
    assert_equal(true,        user.email_names_reviewer)
    assert_equal(false,       user.email_observations_all)
    assert_equal(true,        user.email_observations_consensus)
    assert_equal(true,        user.email_observations_naming)
    assert_equal(:above_species, user.hide_authors)
    assert_equal(:small,      user.image_size)
    assert_equal(false,       user.keep_filenames)
    assert_equal(licenses(:ccnc25), user.license)
    assert_equal('el-GR',     user.locale)
    assert_equal(:scientific, user.location_format)
    assert_equal('new_login', user.login)
    assert_equal(10,          user.rows)
    assert_equal('Agaricus',  user.theme)
    assert_equal(false,       user.thumbnail_maps)
    assert_equal(:small,      user.thumbnail_size)
    assert_equal(false,       user.vertical_layout)
    assert_equal(:yes,        user.votes_anonymous)
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

    # Now change everything. (Note that this user owns no images, so this tests
    # the bulk copyright_holder updater in the boundary case of no images.)
    params = {
      :user => {
        :name       => "new_name",
        :notes      => "new_notes",
        :place_name => "Burbank, California, USA",
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
    assert_flash("error three\nerror four")
    flash[:rendered_notice] = nil

    get_without_clearing_flash(:test_flash, :error => 'error five')
    assert_flash("error three\nerror four\nerror five")
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

  def test_api_key_manager
    ApiKey.all.each(&:destroy)
    assert_equal(0, ApiKey.count)

    # Get initial (empty) form.
    requires_login(:api_keys)
    assert_select('a[href*=edit_api_key]', :count => 0)
    assert_input_value(:key_notes, '')

    # Try to create key with no name.
    login('mary')
    post(:api_keys, :commit => :account_api_keys_create_button.l)
    assert_flash_error
    assert_equal(0, ApiKey.count)
    assert_select('a[href*=edit_api_key]', :count => 0)

    # Create good key.
    post(:api_keys, :commit => :account_api_keys_create_button.l, :key => {:notes => 'app name'})
    assert_flash_success
    assert_equal(1, ApiKey.count)
    assert_equal(1, @mary.reload.api_keys.length)
    key1 = @mary.api_keys.first
    assert_equal('app name', key1.notes)
    assert_select('a[href*=edit_api_key]', :count => 1)

    # Create another key.
    post(:api_keys, :commit => :account_api_keys_create_button.l, :key => {:notes => 'another name'})
    assert_flash_success
    assert_equal(2, ApiKey.count)
    assert_equal(2, @mary.reload.api_keys.length)
    key2 = @mary.api_keys.last
    assert_equal('another name', key2.notes)
    assert_select('a[href*=edit_api_key]', :count => 2)

    # Press "remove" without selecting anything.
    post(:api_keys, :commit => :account_api_keys_remove_button.l)
    assert_flash_warning
    assert_equal(2, ApiKey.count)
    assert_select('a[href*=edit_api_key]', :count => 2)

    # Remove first key.
    post(:api_keys, :commit => :account_api_keys_remove_button.l, "key_#{key1.id}" => '1')
    assert_flash_success
    assert_equal(1, ApiKey.count)
    assert_equal(1, @mary.reload.api_keys.length)
    key = @mary.api_keys.last
    assert_objs_equal(key, key2)
    assert_select('a[href*=edit_api_key]', :count => 1)
  end

  def test_edit_api_key
    key = @mary.api_keys.create(:notes => 'app name')

    # Try without logging in.
    get(:edit_api_key, :id => key.id)
    assert_response(:redirect)

    # Try to edit another user's key.
    login('dick')
    get(:edit_api_key, :id => key.id)
    assert_response(:redirect)

    # Have Mary edit her own key.
    login('mary')
    get(:edit_api_key, :id => key.id)
    assert_response(:success)
    assert_input_value(:key_notes, 'app name')

    # Cancel form.
    post(:edit_api_key, :commit => :CANCEL.l, :id => key.id)
    assert_response(:redirect)
    assert_equal('app name', key.reload.notes)

    # Try to change notes to empty string.
    post(:edit_api_key, :commit => :UPDATE.l, :id => key.id, :key => {:notes => ''})
    assert_flash_error
    assert_response(:success) # means failure

    # Change notes correctly.
    post(:edit_api_key, :commit => :UPDATE.l, :id => key.id, :key => {:notes => 'new name'})
    assert_flash_success
    assert_response(:action => :api_keys)
    assert_equal('new name', key.reload.notes)
  end
end
