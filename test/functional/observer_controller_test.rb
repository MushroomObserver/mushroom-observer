require File.dirname(__FILE__) + '/../test_helper'
require 'observer_controller'
require 'fileutils'

# Re-raise errors caught by the controller.
class ObserverController; def rescue_action(e) raise e end; end

# Create subclasses of StringIO and File that have a content_type member
# to replicate the dynamic method addition that happens in Rails
# cgi.rb.
class StringIOPlus < StringIO
  attr_accessor :content_type
end

class FilePlus < File
  attr_accessor :content_type
end

class ObserverControllerTest < Test::Unit::TestCase
  fixtures :observations
  fixtures :namings
  fixtures :users
  fixtures :images
  fixtures :images_observations
  fixtures :names
  fixtures :rss_logs
  fixtures :licenses
  fixtures :votes
  fixtures :naming_reasons
  fixtures :locations

  def setup
    @controller = ObserverController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    # FileUtils.cp_r(IMG_DIR.gsub(/test_images$/, 'setup_images'), IMG_DIR)
  end

  def teardown
    if File.exists?(IMG_DIR)
      FileUtils.rm_rf(IMG_DIR)
    end
  end

  # ----------------------------
  #  General tests.
  # ----------------------------

  def test_index
    get_with_dump :index
    assert_response :success
    assert_template 'list_rss_logs'
    # Test this fancy new link assertion.
    assert_link_in_html 'Introduction', :action => 'intro'
    assert_link_in_html 'Create Account', :controller => 'account', :action => 'signup'
  end

  def test_ask_webmaster_question
    get_with_dump :ask_webmaster_question
    assert_response :success
    assert_template 'ask_webmaster_question'
    assert_form_action :action => 'ask_webmaster_question'
  end

  def test_color_themes
    get_with_dump :color_themes
    assert_response :success
    assert_template 'color_themes'
    for theme in CSS
      get_with_dump theme
      assert_response :success
      assert_template theme
    end
  end

  def test_how_to_use
    get_with_dump :how_to_use
    assert_response :success
    assert_template 'how_to_use'
  end

  def test_intro
    get_with_dump :intro
    assert_response :success
    assert_template 'intro'
  end

  def test_list_observations
    get_with_dump :list_observations
    assert_response :success
    assert_template 'list_observations'
  end

  def test_list_rss_logs
    get_with_dump :list_rss_logs
    assert_response :success
    assert_template 'list_rss_logs'
  end

  def test_news
    get_with_dump :news
    assert_response :success
    assert_template 'news'
  end

  def test_next_observation
    @request.session[:observation_ids] = [1, 2, 3]
    get_with_dump :next_observation, :id => 1
    assert_redirected_to(:controller => "observer", :action => "show_observation", :id => 2)
  end

  def test_observations_by_name
    get_with_dump :observations_by_name
    assert_response :success
    assert_template 'list_observations'
  end

  def test_pattern_search
    get_with_dump :pattern_search, {:commit => nil, :search => {:pattern => "12"}}
    assert_redirected_to(:controller => "observer", :action => "observation_search")
    assert_equal("12", @request.session[:pattern])
    get_with_dump :pattern_search, {:commit => 'Images', :search => {:pattern => "34"}}
    assert_redirected_to(:controller => "image", :action => "image_search")
    assert_equal("34", @request.session[:pattern])
    get_with_dump :pattern_search, {:commit => 'Names', :search => {:pattern => "56"}}
    assert_redirected_to(:controller => "name", :action => "name_search")
    assert_equal("56", @request.session[:pattern])
    get_with_dump :pattern_search, {:commit => 'Locations', :search => {:pattern => "78"}}
    assert_redirected_to(:controller => "location", :action => "list_place_names", :pattern => "78")
  end

  def test_observation_search
    @request.session[:pattern] = "12"
    get_with_dump :observation_search
    assert_response :success
    assert_template 'list_observations'
    assert_equal "Observations matching '12'", @controller.instance_variable_get('@title')
    get_with_dump :observation_search, { :page => 2 }
    assert_response :success
    assert_template 'list_observations'
    assert_equal "Observations matching '12'", @controller.instance_variable_get('@title')
  end

  # Created in response to a bug seen in the wild
  def test_where_search_next_page
    @request.session[:where] = "Burbank"
    params = {
      :page => 2
    }
    get_with_dump(:location_search, params)
    assert_response :success
    assert_template "list_observations"
  end

  # Created in response to a bug seen in the wild
  def test_where_search_pattern
    params = {
      :pattern => "Burbank"
    }
    get_with_dump(:location_search, params)
    assert_response :success
    assert_template "list_observations"
  end

  def test_prev_observation
    @request.session[:observation_ids] = [1, 2, 3]
    get_with_dump :prev_observation, :id => 1
    assert_redirected_to(:controller => "observer", :action => "show_observation", :id => 3)
  end

  def test_rss
    get_with_dump :rss
    assert_response :success
    assert_template 'rss'
  end

  def test_send_webmaster_question
    post :ask_webmaster_question, "user" => {"email" => "rolf@mushroomobserver.org"}, "question" => {"content" => "Some content"}
    assert_redirected_to(:controller => "observer", :action => "list_rss_logs")

    flash[:notice] = nil
    post :ask_webmaster_question, "user" => {"email" => ""}, "question" => {"content" => "Some content"}
    assert_equal("You must provide a valid return address.", flash[:test_notice])
    assert_response :success

    flash[:notice] = nil
    post :ask_webmaster_question, "user" => {"email" => "spammer"}, "question" => {"content" => "Some content"}
    assert_equal("You must provide a valid return address.", flash[:test_notice])
    assert_response :success

    flash[:notice] = nil
    post :ask_webmaster_question, "user" => {"email" => "forgot@content"}, "question" => {"content" => ""}
    assert_equal("Missing question or content.", flash[:test_notice])
    assert_response :success

    flash[:notice] = nil
    post :ask_webmaster_question, "user" => {"email" => "spam@spam.spam"}, "question" => {"content" => "Buy <a href='http://junk'>Me!</a>"}
    assert_equal("To cut down on robot spam, questions from unregistered users cannot contain 'http:' or HTML markup.", flash[:test_notice])
    assert_response :success
  end

  def test_show_observation
    get_with_dump :show_observation, :id => @coprinus_comatus_obs.id
    assert_response :success
    assert_template 'show_observation'
    assert_form_action :action => 'show_observation'
  end

  # Test a naming owned by the observer but the observer has 'No Opinion'.
  # This is a regression test for a bug in _show_namings.rhtml
  def test_show_observation_no_opinion
    # login as rolf
    user = User.authenticate("rolf", "testpassword")
    assert(user)
    @request.session['user'] = user

    # ensure that rolf owns @obs_with_no_opinion
    assert(user == @strobilurus_diminutivus_obs.user)

    get_with_dump :show_observation, :id => @strobilurus_diminutivus_obs.id
    assert_response :success
    assert_template 'show_observation'
  end

  def test_show_rss_log
    get_with_dump :show_rss_log, :id => 1
    assert_response :success
    assert_template 'show_rss_log'
  end

  def test_users_by_contribution
    get_with_dump :users_by_contribution
    assert_response :success
    assert_template 'users_by_contribution'
  end

  def test_show_user
    get_with_dump :show_user, :id => 1
    assert_response :success
    assert_template 'show_user'
  end

  def test_show_user_no_id
    assert_raises(ActiveRecord::RecordNotFound, "Couldn't find User without an ID") do
      get_with_dump :show_user
    end
  end

  def test_show_site_stats
    get_with_dump :show_site_stats
    assert_response :success
    assert_template 'show_site_stats'
  end

  def test_show_user_observations
    get_with_dump :show_user_observations, :id => 1
    assert_response :success
    assert_template 'list_observations'
  end

  def test_ask_observation_question
    id = @coprinus_comatus_obs.id
    requires_login :ask_observation_question, {:id => id}
    assert_form_action :action => 'send_observation_question', :id => id
  end

  def test_ask_user_question
    id = @mary.id
    requires_login :ask_user_question, {:id => id}
    assert_form_action :action => 'send_user_question', :id => id
  end

  def test_commercial_inquiry
    id = @in_situ.id
    requires_login :commercial_inquiry, {:id => id}
    assert_form_action :action => 'send_commercial_inquiry', :id => id
  end

  def test_destroy_observation
    obs = @minimal_unknown
    assert(obs)
    id = obs.id
    params = {"id"=>id.to_s}
    assert("mary" == obs.user.login)
    requires_user(:destroy_observation, ["observer", "show_observation"], params, false, "mary")
    assert_redirected_to(:controller => "observer", :action => "list_observations")
    assert_raises(ActiveRecord::RecordNotFound) do
      obs = Observation.find(id) # Need to reload observation to pick up changes
    end
  end

  def test_email_features
    page = :email_features
    get(page) # Expect redirect
    assert_redirected_to(:controller => "account", :action => "login")
    user = User.authenticate("rolf", "testpassword")
    assert(user)
    session['user'] = user
    get(page) # Expect redirect
    assert_redirected_to(:controller => "observer", :action => "list_observations")
    user.id = 0 # Make user the admin
    session['user'] = user
    get_with_dump(page)
    assert_response :success
    assert_template page.to_s
    assert_form_action :action => 'send_feature_email'
  end

  def test_login
    get_with_dump :login
    assert_redirected_to(:controller => "account", :action => "login")
  end

  def test_send_commercial_inquiry
    image = @commercial_inquiry_image
    params = {
      :id => image.id,
      :commercial_inquiry => {
        :content => "Testing commercial_inquiry"
      }
    }
    requires_login :send_commercial_inquiry, params, false
    assert_redirected_to(:controller => "observer", :action => "show_image")
  end

  def test_send_feature_email
    params = {
      :feature_email => {
        :content => "Testing feature announcement"
      }
    }
    page = :send_feature_email
    get(page, params) # Expect redirect
    assert_redirected_to(:controller => "account", :action => "login")
    user = User.authenticate("rolf", "testpassword")
    assert(user)
    session['user'] = user
    get(page, params) # Expect redirect
    assert_redirected_to(:controller => "observer", :action => "list_rss_logs")
    assert_equal("Only the admin can send feature mail.", flash[:notice])
    user.id = 0 # Make user the admin
    session['user'] = user
    get(page, params) # Expect redirect
    assert_redirected_to(:controller => "observer", :action => "users_by_name")
  end

  def test_send_observation_question
    obs = @minimal_unknown
    params = {
      :id => obs.id,
      :question => {
        :content => "Testing question"
      }
    }
    requires_login :send_observation_question, params, false
    assert_equal("Delivered question.", flash[:notice])
    assert_redirected_to(:controller => "observer", :action => "show_observation")
  end

  def test_send_user_question
    user = @mary
    params = {
      :id => user.id,
      :email => {
        :subject => "Email subject",
        :content => "Email content"
      }
    }
    requires_login :send_user_question, params, false
    assert_equal("Delivered email.", flash[:notice])
    assert_redirected_to(:controller => "observer", :action => "show_user")
  end

  def test_users_by_name
    page = :users_by_name
    get(page) # Expect redirect
    assert_redirected_to(:controller => "account", :action => "login")
    user = User.authenticate("rolf", "testpassword")
    assert(user)
    session['user'] = user
    get(page) # Exepct redirect
    assert_redirected_to(:controller => "observer", :action => "list_observations")
    user.id = 0 # Make user the admin
    session['user'] = user
    get_with_dump(page)
    assert_response :success
    assert_template page.to_s
  end

  # Make sure languages all have same tags.
  def test_language_tags
    dir = "#{RAILS_ROOT}/lang/ui"
    assert File.directory?(dir)
    tags = {}
    this_tags = {}
    files = Dir.glob("#{dir}/*.yml")
    assert(files.length > 0)
    for file in files
      h = this_tags[file] = {}
      for line in IO.readlines(file)
        h[$1] = tags[$1] = true if line.match(/^(\w+)/)
      end
      assert(h["app_banner"])
    end
    for file in files
      missing = tags.keys - this_tags[file].keys
      assert_equal([], missing)
    end
  end

  # ------------------------------
  #  Test creating observations.
  # ------------------------------

  # Test "get" side of create_observation.
  def test_create_observation
    requires_login :create_observation
    assert_form_action :action => 'create_observation', :approved_name => ''
  end

  # Test constructing observations in various ways (with minimal namings).
  def test_construct_observation_generic(params, observation_count, naming_count, name_count)
    o_count = Observation.find(:all).length
    g_count = Naming.find(:all).length
    n_count = Name.find(:all).length
    params[:observation] = {}                   if !params[:observation]
    params[:observation][:where] = "right here" if !params[:observation][:where]
    params[:observation]["when(1i)"] = "2007"
    params[:observation]["when(2i)"] = "3"
    params[:observation]["when(3i)"] = "9"
    params[:observation][:specimen]  = "0"
    params[:vote] = {}            if !params[:vote]
    params[:vote][:value] = "3" if !params[:vote][:value]
    post_requires_login(:create_observation, params, false)
    if observation_count == 1
      assert_redirected_to(:controller => "observer", :action => "show_observation")
    else
      assert_response(:success)
    end
    assert((o_count + observation_count) == Observation.find(:all).length)
    assert((g_count + naming_count) == Naming.find(:all).length)
    assert((n_count + name_count
    ) == Name.find(:all).length)
  end

  def test_construct_observation_simple
    # Test a simple observation creation with an approved unique name
    where = "test_construct_observation_simple"
    test_construct_observation_generic({
      :observation => { :where => where },
      :name => { :name => "Coprinus comatus" }
    }, 1,1,0)
    obs = assigns(:observation)
    nam = assigns(:naming)
    assert_equal(where, obs.where) # Make sure it's the right observation
    assert_equal(@coprinus_comatus, nam.name) # Make sure it's the right name
    assert_not_nil(obs.rss_log)
  end

  def test_construct_observation_unknown
    # Test a simple observation creation of an unknown
    where = "test_construct_observation_unknown"
    test_construct_observation_generic({
      :observation => { :where => where },
      :name => { :name => "Unknown" }
    }, 1,0,0)
    obs = assigns(:observation)
    assert_equal(where, obs.where) # Make sure it's the right observation
    assert_not_nil(obs.rss_log)
  end

  def test_construct_observation_new_name
    # Test an observation creation with a new name
    test_construct_observation_generic({
      :name => { :name => "New name" }
    }, 0,0,0)
  end

  def test_construct_observation_approved_new_name
    # Test an observation creation with an approved new name
    new_name = "Argus arg-arg"
    test_construct_observation_generic({
      :name => { :name => new_name },
      :approved_name => new_name
    }, 1,1,2)
  end

  def test_construct_observation_approved_section
    # Test an observation creation with an approved section (should fail)
    new_name = "Argus section Argus"
    test_construct_observation_generic({
      :name => { :name => new_name },
      :approved_name => new_name
    }, 0,0,0)
  end

  def test_construct_observation_approved_junk
    # Test an observation creation with an approved junk name
    new_name = "This is a bunch of junk"
    test_construct_observation_generic({
      :name => { :name => new_name },
      :approved_name => new_name
    }, 0,0,0)
  end

  def test_construct_observation_multiple_match
    # Test an observation creation with multiple matches
    test_construct_observation_generic({
      :name => { :name => "Amanita baccata" }
    }, 0,0,0)
  end

  def test_construct_observation_chosen_multiple_match
    # Test an observation creation with one of the multiple matches chosen
    test_construct_observation_generic({
      :name => { :name => "Amanita baccata" },
      :chosen_name => { :name_id => @amanita_baccata_arora.id }
    }, 1,1,0)
  end

  def test_construct_observation_deprecated_multiple_match
    # Test an observation creation with one of the multiple matches chosen
    test_construct_observation_generic({
      :name => { :name => @pluteus_petasatus_deprecated.text_name }
    }, 1,1,0)
    nam = assigns(:naming)
    assert_equal(@pluteus_petasatus_approved, nam.name)
  end

  def test_construct_observation_deprecated
    # Test an observation creation with a deprecated name
    test_construct_observation_generic({
      :name => { :name => "Lactarius subalpinus" }
    }, 0,0,0)
  end

  def test_construct_observation_chosen_deprecated
    # Test an observation creation with a deprecated name, but a chosen approved alternative
    new_name = "Lactarius subalpinus"
    test_construct_observation_generic({
      :name => { :name => new_name },
      :approved_name => new_name,
      :chosen_name => { :name_id => @lactarius_alpinus.id }
    }, 1,1,0)
    nam = assigns(:naming)
    assert(nam.name, @lactarius_alpinus)
  end

  def test_construct_observation_approved_deprecated
    # Test an observation creation with a deprecated name that has been approved
    new_name = "Lactarius subalpinus"
    test_construct_observation_generic({
      :name => { :name => new_name },
      :approved_name => new_name,
      :chosen_name => { }
    }, 1,1,0)
    nam = assigns(:naming)
    assert_equal(nam.name, @lactarius_subalpinus)
  end

  def test_construct_observation_approved_new_species
    # Test an observation creation with an approved new name
    new_name = "Agaricus novus"
    test_construct_observation_generic({
      :name => { :name => new_name },
      :approved_name => new_name
    }, 1,1,1)
    name = Name.find_by_text_name(new_name)
    assert(name)
    assert_equal(new_name, name.text_name)
  end

  # This is no longer necessary as it will add the author immediately now without confirmation. [JPH -20080227]
  # def test_construct_observation_approved_new_author
  #   # Test an observation creation with an approved new name
  #   name = @strobilurus_diminutivus_no_author
  #   assert_nil(name.author)
  #   author = 'Desjardin'
  #   new_name = "#{name.text_name} #{author}"
  #   test_construct_observation_generic({
  #     :name => { :name => new_name },
  #     :approved_name => new_name
  #   }, 1,1,1)
  #   name = Name.find(name.id)
  #   assert_equal(author, name.author)
  # end

  # ----------------------------------------------------------------
  #  Test edit_observation and edit_naming, both "get" and "post".
  # ----------------------------------------------------------------

  # (Sorry, these used to all be edit/update_observation, now they're
  # confused because of the naming stuff.)
  def test_edit_observation
    obs = @coprinus_comatus_obs
    assert("rolf" == obs.user.login)
    params = { :id => obs.id.to_s }
    requires_user(:edit_observation, ["observer", "show_observation"], params)
    assert_form_action :action => 'edit_observation'
  end

  def test_update_observation
    obs = @detailed_unknown
    modified = obs.rss_log.modified
    new_where = "test_update_observation"
    new_notes = "blather blather blather"
    new_specimen = false
    params = {
      :id => obs.id.to_s,
      :observation => {
        :where => new_where,
        "when(1i)" => "2001",
        "when(2i)" => "2",
        "when(3i)" => "3",
        :notes => new_notes,
        :specimen => new_specimen
      },
      :log_change => { :checked => '1' }
    }
    post_requires_user(:edit_observation, ["observer", "show_observation"], params, false, "mary")
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs = assigns(:observation)
    assert_equal(new_where, obs.where)
    assert_equal("2001-02-03", obs.when.to_s)
    assert_equal(new_notes, obs.notes)
    assert_equal(new_specimen, obs.specimen)
    assert_not_equal(modified, obs.rss_log.modified)
  end

  def test_update_observation_no_logging
    obs = @detailed_unknown
    modified = obs.rss_log.modified
    where = "test_update_observation_no_logging"
    params = {
      :id => obs.id.to_s,
      :observation => {
        :where => where,
        :when => obs.when,
        :notes => obs.notes,
        :specimen => obs.specimen
      },
      :log_change => { :checked => '0' }
    }
    post_requires_user(:edit_observation, ["observer", "show_observation"], params, false, "mary")
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs = assigns(:observation)
    assert_equal(where, obs.where)
    assert_equal(modified, obs.rss_log.modified)
  end

  # ----------------------------
  #  Test namings.
  # ----------------------------

  # Now test the naming part of it.
  def test_create_naming_get
    obs = @coprinus_comatus_obs
    params = {
      :id => obs.id.to_s
    }
    requires_login(:create_naming, params, false)
    assert_form_action :action => 'create_naming', :approved_name => ''
  end

  # Now test the naming part of it.
  def test_edit_naming_get
    nam = @coprinus_comatus_naming
    params = {
      :id => nam.id.to_s
    }
    requires_user(:edit_naming, ["observer", "show_observation"], params, false)
    assert_form_action :action => 'edit_naming', :approved_name => nam.text_name
  end

  def test_update_observation_new_name
    nam = @coprinus_comatus_naming
    old_name = nam.text_name
    new_name = "Easter bunny"
    params = {
      :id => nam.id.to_s,
      :name => { :name => new_name }
    }
    post_requires_user(:edit_naming, ["observer", "show_observation"], params, false)
    assert_response(:success)
    assert_template("edit_naming")
    obs = assigns(:naming)
    assert_not_equal(new_name, nam.text_name)
    assert_equal(old_name, nam.text_name)
  end

  def test_update_observation_approved_new_name
    nam = @coprinus_comatus_naming
    old_name = nam.text_name
    new_name = "Easter bunny"
    params = {
      :id => nam.id.to_s,
      :name => { :name => new_name },
      :approved_name => new_name
    }
    post_requires_user(:edit_naming, ["observer", "show_observation"], params, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    nam = assigns(:naming)
    assert_equal(new_name, nam.text_name)
    assert_not_equal(old_name, nam.text_name)
    assert(!nam.name.deprecated)
  end

  def test_update_observation_multiple_match
    nam = @coprinus_comatus_naming
    old_name = nam.text_name
    new_name = "Amanita baccata"
    params = {
      :id => nam.id.to_s,
      :name => { :name => new_name }
    }
    post_requires_user(:edit_naming, ["observer", "show_observation"], params, false)
    assert_response(:success)
    assert_template("edit_naming")
    nam = assigns(:naming)
    assert_not_equal(new_name, nam.text_name)
    assert_equal(old_name, nam.text_name)
  end

  def test_update_observation_chosen_multiple_match
    nam = @coprinus_comatus_naming
    old_name = nam.text_name
    new_name = "Amanita baccata"
    params = {
      :id => nam.id.to_s,
      :name => { :name => new_name },
      :chosen_name => { :name_id => @amanita_baccata_arora.id }
    }
    post_requires_user(:edit_naming, ["observer", "show_observation"], params, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    nam = assigns(:naming)
    assert_equal(new_name, nam.name.text_name)
    assert_equal(new_name + " sensu Arora", nam.text_name)
    assert_not_equal(old_name, nam.text_name)
  end

  def test_update_observation_deprecated
    nam = @coprinus_comatus_naming
    old_name = nam.text_name
    new_name = "Lactarius subalpinus"
    params = {
      :id => nam.id.to_s,
      :name => { :name => new_name }
    }
    post_requires_user(:edit_naming, ["observer", "show_observation"], params, false)
    assert_response(:success)
    assert_template("edit_naming")
    nam = assigns(:naming)
    assert_not_equal(new_name, nam.text_name)
    assert_equal(old_name, nam.text_name)
  end

  def test_update_observation_chosen_deprecated
    nam = @coprinus_comatus_naming
    start_name = nam.name
    new_name = "Lactarius subalpinus"
    chosen_name = @lactarius_alpinus
    params = {
      :id => nam.id.to_s,
      :name => { :name => new_name },
      :approved_name => new_name,
      :chosen_name => { :name_id => chosen_name.id }
    }
    post_requires_user(:edit_naming, ["observer", "show_observation"], params, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    nam = assigns(:naming)
    assert_not_equal(start_name, nam.name)
    assert_equal(chosen_name, nam.name)
  end

  def test_update_observation_accepted_deprecated
    nam = @coprinus_comatus_naming
    start_name = nam.name
    new_text_name = @lactarius_subalpinus.text_name
    params = {
      :id => nam.id.to_s,
      :name => { :name => new_text_name },
      :approved_name => new_text_name,
      :chosen_name => { }
    }
    post_requires_user(:edit_naming, ["observer", "show_observation"], params, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    nam = assigns(:naming)
    assert_not_equal(start_name, nam.name)
    assert_equal(new_text_name, nam.name.text_name)
  end

  # ------------------------------------------------------------
  #  Test proposing new names, casting and changing votes, and
  #  setting and changing preferred_namings.
  # ------------------------------------------------------------

  # This is the standard case, nothing unusual or stressful here.
  def test_propose_naming
    o_count = Observation.find(:all).length
    g_count = Naming.find(:all).length
    n_count = Name.find(:all).length
    v_count = Vote.find(:all).length
    nr_count = NamingReason.find(:all).length
    #
    # Make a few assertions up front to make sure fixtures are as expected.
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.name)
    assert(@coprinus_comatus_naming.user_voted?(@rolf))
    assert(@coprinus_comatus_naming.user_voted?(@mary))
    assert(!@coprinus_comatus_naming.user_voted?(@dick))
    assert(@coprinus_comatus_other_naming.user_voted?(@rolf))
    assert(@coprinus_comatus_other_naming.user_voted?(@mary))
    assert(!@coprinus_comatus_other_naming.user_voted?(@dick))
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.preferred_name(@rolf))
    assert_equal(@agaricus_campestris, @coprinus_comatus_obs.preferred_name(@mary))
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.preferred_name(@dick))
    #
    # Rolf, the owner of @coprinus_comatus_obs, already has a naming, which
    # he's 80% sure of.  Create a new one (the genus Agaricus) that he's 100%
    # sure of.  (Mary also has a naming with two votes.)
    params = {
      :id => @coprinus_comatus_obs.id,
      :name => { :name => "Agaricus" },
      :vote => { :value => "3" },
      :reason => {
        "1" => { :check => "1", :notes => "Looks good to me." },
        "2" => { :check => "1", :notes => "" },
        "3" => { :check => "0", :notes => "Spore texture." },
        "4" => { :check => "0", :notes => "" }
      }
    }
    post_requires_login(:create_naming, params, false)
    #
    # Make sure the right number of objects were created.
    assert_equal(o_count + 0, Observation.find(:all).length)
    assert_equal(g_count + 1, Naming.find(:all).length)
    assert_equal(n_count + 0, Name.find(:all).length)
    assert_equal(v_count + 1, Vote.find(:all).length)
    assert_equal(nr_count + 3, NamingReason.find(:all).length)
    #
    # Make sure everything I need is reloaded.
    @coprinus_comatus_obs.reload
    #
    # Get new objects.
    naming = Naming.find(:all).last
    vote = Vote.find(:all).last
    #
    # Make sure observation was updated and referenced correctly.
    assert_equal(3, @coprinus_comatus_obs.namings.length)
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.name)
    #
    # Make sure naming was created correctly and referenced.
    assert_equal(@coprinus_comatus_obs, naming.observation)
    assert_equal(@agaricus, naming.name)
    assert_equal(@rolf, naming.user)
    assert_equal(3, naming.naming_reasons.length)
    assert_equal(1, naming.votes.length)
    #
    # Make sure vote was created correctly.
    assert_equal(naming, vote.naming)
    assert_equal(@rolf, vote.user)
    assert_equal(3, vote.value)
    #
    # Make sure reasons were created correctly.
    nr1 = naming.naming_reasons[0]
    nr2 = naming.naming_reasons[1]
    nr3 = naming.naming_reasons[2]
    nr4 = NamingReason.new
    assert_equal(naming, nr1.naming)
    assert_equal(naming, nr2.naming)
    assert_equal(naming, nr3.naming)
    assert_equal(1, nr1.reason)
    assert_equal(2, nr2.reason)
    assert_equal(3, nr3.reason)
    assert_equal("Looks good to me.", nr1.notes)
    assert_equal("", nr2.notes)
    assert_equal("Spore texture.", nr3.notes)
    assert(nr1.check)
    assert(nr2.check)
    assert(nr3.check)
    assert(!nr4.check)
    #
    # Make sure a few random methods work right, too.
    assert_equal(3, naming.vote_sum)
    assert_equal(vote, naming.users_vote(@rolf))
    assert(naming.user_voted?(@rolf))
    assert(!naming.user_voted?(@mary))
    assert_equal(@agaricus, @coprinus_comatus_obs.preferred_name(@rolf))
    assert_equal(@agaricus_campestris, @coprinus_comatus_obs.preferred_name(@mary))
  end

  # Now see what happens when rolf's new naming is less confident than old.
  def test_propose_uncertain_naming
    g_count = Naming.find(:all).length
    params = {
      :id => @coprinus_comatus_obs.id,
      :name => { :name => "Agaricus" },
      :vote => { :value => "-1" },
    }
    post_requires_login(:create_naming, params, false)
    #
    # Make sure everything I need is reloaded.
    @coprinus_comatus_obs.reload
    @coprinus_comatus_naming.reload
    #
    # Get new objects.
    naming = Naming.find(:all).last
    #
    # Make sure observation was updated right.
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.name)
    #
    # Make sure preferred_namings are right.
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.preferred_name(@rolf))
    assert_equal(@agaricus_campestris, @coprinus_comatus_obs.preferred_name(@mary))
    #
    # Sure, check the votes, too, while we're at it.
    assert_equal(3, @coprinus_comatus_naming.vote_sum) # 2+1 = 3
  end

  # Now see what happens when a third party proposes a name, and it wins.
  def test_propose_dicks_naming
    o_count = Observation.find(:all).length
    g_count = Naming.find(:all).length
    n_count = Name.find(:all).length
    v_count = Vote.find(:all).length
    nr_count = NamingReason.find(:all).length
    #
    # Dick proposes "Conocybe filaris" out of the blue.
    params = {
      :id => @coprinus_comatus_obs.id,
      :name => { :name => "Conocybe filaris" },
      :vote => { :value => "3" },
    }
    post_requires_login(:create_naming, params, false, "dick")
    naming = Naming.find(:all).last
    #
    # Make sure the right number of objects were created.
    assert_equal(o_count + 0, Observation.find(:all).length)
    assert_equal(g_count + 1, Naming.find(:all).length)
    assert_equal(n_count + 0, Name.find(:all).length)
    assert_equal(v_count + 1, Vote.find(:all).length)
    assert_equal(nr_count + 1, NamingReason.find(:all).length)
    #
    # Make sure everything I need is reloaded.
    @coprinus_comatus_obs.reload
    @coprinus_comatus_naming.reload
    @coprinus_comatus_other_naming.reload
    #
    # Check votes.
    assert_equal(3, @coprinus_comatus_naming.vote_sum)
    assert_equal(0, @coprinus_comatus_other_naming.vote_sum)
    assert_equal(3, naming.vote_sum)
    assert_equal(2, @coprinus_comatus_naming.votes.length)
    assert_equal(2, @coprinus_comatus_other_naming.votes.length)
    assert_equal(1, naming.votes.length)
    #
    # Make sure observation was updated right.
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.name)
    #
    # Make sure preferred_namings are right.
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.preferred_name(@rolf))
    assert_equal(@agaricus_campestris, @coprinus_comatus_obs.preferred_name(@mary))
    assert_equal(@conocybe_filaris, @coprinus_comatus_obs.preferred_name(@dick))
  end

  # Test a bug in name resolution: was failing to recognize that
  # "Genus species (With) Author" was recognized even if "Genus species"
  # was already in the database.
  def test_create_naming_with_author_when_name_without_author_already_exists
    params = {
      :id => @coprinus_comatus_obs.id,
      :name => { :name => "Conocybe filaris (With) Author" },
      :vote => { :value => "3" },
    }
    post_requires_login(:create_naming, params, false, "dick")
    naming = Naming.find(:all).last
    assert_redirected_to(:controller => "observer", :action => "show_observation", :id => @coprinus_comatus_obs.id)
    assert_equal("Conocybe filaris", naming.name.text_name)
    assert_equal("(With) Author", naming.name.author)
    assert_equal(@conocybe_filaris.id, naming.name_id)
  end

  # ----------------------------
  #  Test voting.
  # ----------------------------

  # Now have Dick vote on Mary's name.
  # Votes: rolf=2/-3, mary=1/3, dick=-1/3
  # Rolf prefers naming 3 (vote 2 -vs- -3).
  # Mary prefers naming 9 (vote 1 -vs- 3).
  # Dick now prefers naming 9 (vote 3).
  # Summing, 3 gets 2+1/3=1, 9 gets -3+3+3/4=.75, so 3 gets it.
  def test_cast_vote_dick
    params = {
      :vote => {
        :value     => "3",
        :naming_id => @coprinus_comatus_other_naming.id
      }
    }
    post_requires_login(:cast_vote, params, false, "dick")
    #
    # Make sure everything I need is reloaded.
    @coprinus_comatus_obs.reload
    @coprinus_comatus_naming.reload
    @coprinus_comatus_other_naming.reload
    #
    # Check votes.
    assert_equal(3, @coprinus_comatus_naming.vote_sum)
    assert_equal(2, @coprinus_comatus_naming.votes.length)
    assert_equal(3, @coprinus_comatus_other_naming.vote_sum)
    assert_equal(3, @coprinus_comatus_other_naming.votes.length)
    #
    # Make sure observation was updated right.
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.name)
    #
    # Make sure preferred_namings are right.
    assert_equal(@coprinus_comatus,    @coprinus_comatus_obs.preferred_name(@rolf))
    assert_equal(@agaricus_campestris, @coprinus_comatus_obs.preferred_name(@mary))
    assert_equal(@agaricus_campestris, @coprinus_comatus_obs.preferred_name(@dick))
    #
    # If Dick votes on the other as well, then his first vote should
    # get demoted and his preference should change.
    # Summing, 3 gets 2+1+3/4=1.5, 9 gets -3+3+2/4=.5, so 3 keeps it.
    @coprinus_comatus_naming.change_vote(@dick, 3)
    @coprinus_comatus_obs.reload
    @coprinus_comatus_naming.reload
    @coprinus_comatus_other_naming.reload
    assert_equal(3, @coprinus_comatus_naming.users_vote(@dick).value)
    assert_equal(6, @coprinus_comatus_naming.vote_sum)
    assert_equal(3, @coprinus_comatus_naming.votes.length)
    assert_equal(2, @coprinus_comatus_other_naming.users_vote(@dick).value)
    assert_equal(2, @coprinus_comatus_other_naming.vote_sum)
    assert_equal(3, @coprinus_comatus_other_naming.votes.length)
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.preferred_name(@dick))
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.name)
  end

  # Now have Rolf change his vote on his own naming. (no change in prefs)
  # Votes: rolf=3->2/-3, mary=1/3, dick=x/x
  def test_cast_vote_rolf_change
    params = {
      :vote => {
        :value     => "2",
        :naming_id => @coprinus_comatus_naming.id
      }
    }
    post_requires_login(:cast_vote, params, false, "rolf")
    #
    # Make sure everything I need is reloaded.
    @coprinus_comatus_obs.reload
    @coprinus_comatus_naming.reload
    @coprinus_comatus_other_naming.reload
    #
    # Make sure observation was updated right.
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.name)
    #
    # Make sure preferred_naming is right.
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.preferred_name(@rolf))
    #
    # Check vote.
    assert_equal(3, @coprinus_comatus_naming.vote_sum)
    assert_equal(2, @coprinus_comatus_naming.votes.length)
  end

  # Now have Rolf increase his vote for Mary's. (changes consensus)
  # Votes: rolf=2/-3->3, mary=1/3, dick=x/x
  def test_cast_vote_rolf_second_greater
    params = {
      :vote => {
        :value     => "3",
        :naming_id => @coprinus_comatus_other_naming.id
      }
    }
    post_requires_login(:cast_vote, params, false, "rolf")
    #
    # Make sure everything I need is reloaded.
    @coprinus_comatus_obs.reload
    @coprinus_comatus_naming.reload
    @coprinus_comatus_other_naming.reload
    #
    # Make sure observation was updated right.
    assert_equal(@agaricus_campestris, @coprinus_comatus_obs.name)
    #
    # Make sure preferred_naming is right.
    assert_equal(@agaricus_campestris, @coprinus_comatus_obs.preferred_name(@rolf))
    #
    # Check vote.
    @coprinus_comatus_other_naming.reload
    assert_equal(6, @coprinus_comatus_other_naming.vote_sum)
    assert_equal(2, @coprinus_comatus_other_naming.votes.length)
  end

  # Now have Rolf increase his vote for Mary's insufficiently. (no change)
  # Votes: rolf=2/-3->-1, mary=1/3, dick=x/x
  # Summing, 3 gets 2+1=3, 9 gets -1+3=2, so 3 keeps it.
  def test_cast_vote_rolf_second_lesser
    params = {
      :vote => {
        :value     => "-1",
        :naming_id => @coprinus_comatus_other_naming.id
      }
    }
    post_requires_login(:cast_vote, params, false, "rolf")
    #
    # Make sure everything I need is reloaded.
    @coprinus_comatus_obs.reload
    @coprinus_comatus_naming.reload
    @coprinus_comatus_other_naming.reload
    #
    # Make sure observation was updated right.
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.name)
    #
    # Make sure preferred_naming is right.
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.preferred_name(@rolf))
    #
    # Check vote.
    assert_equal(3, @coprinus_comatus_naming.vote_sum)
    assert_equal(2, @coprinus_comatus_other_naming.vote_sum)
    assert_equal(2, @coprinus_comatus_other_naming.votes.length)
  end

  # Now, have Mary delete her vote against Rolf's naming.  This NO LONGER has the effect
  # of excluding Rolf's naming from the consensus calculation due to too few votes.
  # (Have Dick vote first... I forget what this was supposed to test for, but it's clearly
  # superfluous now).
  # Votes: rolf=2/-3, mary=1->x/3, dick=x/x->3
  # Summing after Dick votes,   3 gets 2+1/3=1, 9 gets -3+3+3/4=.75, 3 keeps it.
  # Summing after Mary deletes, 3 gets 2/2=1,   9 gets -3+3+3/4=.75, 3 still keeps it in this voting algorithm, arg.
  def test_cast_vote_mary
    @coprinus_comatus_other_naming.change_vote(@dick, 3)
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.name)
    #
    params = {
      :vote => {
        :value     => Vote.delete_vote,
        :naming_id => @coprinus_comatus_naming.id
      }
    }
    post_requires_login(:cast_vote, params, false, "mary")
    #
    # Make sure everything I need is reloaded.
    @coprinus_comatus_obs.reload
    @coprinus_comatus_naming.reload
    @coprinus_comatus_other_naming.reload
    #
    # Check votes.
    assert_equal(2, @coprinus_comatus_naming.vote_sum)
    assert_equal(1, @coprinus_comatus_naming.votes.length)
    assert_equal(3, @coprinus_comatus_other_naming.vote_sum)
    assert_equal(3, @coprinus_comatus_other_naming.votes.length)
    #
    # Make sure observation is changed correctly.
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.name)
    #
    # Make sure preferred_namings are changed.
    assert_equal(@coprinus_comatus,    @coprinus_comatus_obs.preferred_name(@rolf))
    assert_equal(@agaricus_campestris, @coprinus_comatus_obs.preferred_name(@mary))
  end

  # Rolf can destroy his naming if Mary deletes her vote on it.
  def test_rolf_destroy_rolfs_naming
    # First delete Mary's vote for it.
    @coprinus_comatus_naming.change_vote(@mary, Vote.delete_vote)
    #
    old_naming_id = @coprinus_comatus_naming.id
    old_vote1_id = @coprinus_comatus_owner_vote.id
    old_vote2_id = @coprinus_comatus_other_vote.id
    old_naming_reason_id = @cc_macro_reason.id
    #
    params = {
      :id => @coprinus_comatus_naming.id
    }
    requires_user(:destroy_naming, ['observer', 'show_observation'],
      params, false, "rolf")
    #
    # Make sure everything I need is reloaded.
    @coprinus_comatus_obs.reload
    @coprinus_comatus_other_naming.reload
    #
    # Make sure naming and associated vote and reason were actually destroyed.
    assert_raises(ActiveRecord::RecordNotFound) do
      Naming.find(old_naming_id)
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      Vote.find(old_vote1_id)
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      Vote.find(old_vote2_id)
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      NamingReason.find(old_naming_reason_id)
    end
    #
    # Make sure observation was updated right.
    assert_equal(@agaricus_campestris, @coprinus_comatus_obs.name)
    #
    # Make sure preferred_namings are right.
    assert_equal(@agaricus_campestris, @coprinus_comatus_obs.preferred_name(@rolf))
    assert_equal(@agaricus_campestris, @coprinus_comatus_obs.preferred_name(@mary))
    #
    # Check votes. (should be no change)
    assert_equal(0, @coprinus_comatus_other_naming.vote_sum)
    assert_equal(2, @coprinus_comatus_other_naming.votes.length)
  end

  # Make sure Rolf can't destroy his naming if Dick prefers it.
  def test_rolf_destroy_rolfs_naming_when_dick_prefers_it
    old_naming_id = @coprinus_comatus_naming.id
    old_vote1_id = @coprinus_comatus_owner_vote.id
    old_vote2_id = @coprinus_comatus_other_vote.id
    old_naming_reason_id = @cc_macro_reason.id
    #
    # Make Dick prefer it.
    @coprinus_comatus_naming.change_vote(@dick, 3)
    #
    # Have Rolf try to destroy it.
    params = { :id => @coprinus_comatus_naming.id }
    requires_user(:destroy_naming, ['observer', 'show_observation'],
      params, false, "rolf")
    #
    # Make sure naming and associated vote and reason are still there.
    assert(Naming.find(old_naming_id))
    assert(Vote.find(old_vote1_id))
    assert(Vote.find(old_vote2_id))
    assert(NamingReason.find(old_naming_reason_id))
    #
    # Make sure observation is unchanged.
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.name)
    #
    # Make sure preferred_namings are unchanged (except Dick's).
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.preferred_name(@rolf))
    assert_equal(@agaricus_campestris, @coprinus_comatus_obs.preferred_name(@mary))
    #
    # Check votes are unchanged.
    assert_equal(6, @coprinus_comatus_naming.vote_sum)
    assert_equal(3, @coprinus_comatus_naming.votes.length)
    assert_equal(0, @coprinus_comatus_other_naming.vote_sum)
    assert_equal(2, @coprinus_comatus_other_naming.votes.length)
  end

  # Rolf makes changes to vote and reasons of his naming.  Shouldn't matter
  # whether Mary has voted on it.
  def test_edit_naming_thats_being_used_just_change_reasons
    o_count = Observation.find(:all).length
    g_count = Naming.find(:all).length
    n_count = Name.find(:all).length
    v_count = Vote.find(:all).length
    nr_count = NamingReason.find(:all).length
    #
    # Rolf makes superficial changes to his naming.
    params = {
      :id => @coprinus_comatus_naming.id,
      :name => { :name => @coprinus_comatus.search_name },
      :vote => { :value => "3" },
      :reason => {
        "1" => { :check => "1", :notes => "Change to macro notes." },
        "2" => { :check => "1", :notes => "" },
        "3" => { :check => "0", :notes => "Add some micro notes." },
        "4" => { :check => "0", :notes => "" }
      }
    }
    post_requires_user(:edit_naming, ['observer', 'show_observation'],
      params, false, "rolf")
    #
    # Make sure the right number of objects were created.
    assert_equal(o_count + 0, Observation.find(:all).length)
    assert_equal(g_count + 0, Naming.find(:all).length)
    assert_equal(n_count + 0, Name.find(:all).length)
    assert_equal(v_count + 0, Vote.find(:all).length)
    assert_equal(nr_count + 2, NamingReason.find(:all).length)
    #
    # Make sure everything I need is reloaded.
    @coprinus_comatus_obs.reload
    @coprinus_comatus_naming.reload
    @coprinus_comatus_owner_vote.reload
    #
    # Make sure observation is unchanged.
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.name)
    #
    # Make sure preferred_naming is unchanged.
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.preferred_name(@rolf))
    #
    # Check votes.
    assert_equal(4, @coprinus_comatus_naming.vote_sum) # 2+1 -> 3+1
    assert_equal(2, @coprinus_comatus_naming.votes.length)
    #
    # Check new reasons.
    assert_equal(3, @coprinus_comatus_naming.naming_reasons.length)
    nr1 = @coprinus_comatus_naming.naming_reasons[0]
    nr2 = @coprinus_comatus_naming.naming_reasons[1]
    nr3 = @coprinus_comatus_naming.naming_reasons[2]
    assert_equal(1, nr1.reason)
    assert_equal(2, nr2.reason)
    assert_equal(3, nr3.reason)
    assert_equal("Change to macro notes.", nr1.notes)
    assert_equal("", nr2.notes)
    assert_equal("Add some micro notes.", nr3.notes)
  end

  # Rolf makes changes to name of his naming.  Shouldn't be allowed to do this
  # if Mary has voted on it.  Should clone naming, vote, and reasons.
  def test_edit_naming_thats_being_used_change_name
    o_count = Observation.find(:all).length
    g_count = Naming.find(:all).length
    n_count = Name.find(:all).length
    v_count = Vote.find(:all).length
    nr_count = NamingReason.find(:all).length
    #
    # Now, Rolf makes name change to his naming (leave rest the same).
    params = {
      :id => @coprinus_comatus_naming.id,
      :name => { :name => "Conocybe filaris" },
      :vote => { :value => "2" },
      :reason => {
        "1" => { :check => "1", :notes => "Isn't it obvious?" },
        "2" => { :check => "0", :notes => "" },
        "3" => { :check => "0", :notes => "" },
        "4" => { :check => "0", :notes => "" }
      }
    }
    post_requires_user(:edit_naming, ['observer', 'show_observation'],
      params, false, "rolf")
    #
    # Make sure the right number of objects were created.
    assert_equal(o_count + 0, Observation.find(:all).length)
    assert_equal(g_count + 1, Naming.find(:all).length)
    assert_equal(n_count + 0, Name.find(:all).length)
    assert_equal(v_count + 1, Vote.find(:all).length)
    assert_equal(nr_count + 1, NamingReason.find(:all).length)
    #
    # Get new objects.
    naming = Naming.find(:all).last
    vote = Vote.find(:all).last
    nr = NamingReason.find(:all).last
    #
    # Make sure everything I need is reloaded.
    @coprinus_comatus_obs.reload
    @coprinus_comatus_naming.reload
    @coprinus_comatus_owner_vote.reload
    #
    # Make sure observation is unchanged.
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.name)
    #
    # Make sure preferred_naming is unchanged.
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.preferred_name(@rolf))
    assert_equal(@agaricus_campestris, @coprinus_comatus_obs.preferred_name(@mary))
    #
    # Make sure old naming is unchanged.
    assert_equal(@coprinus_comatus, @coprinus_comatus_naming.name)
    assert_equal(1, @coprinus_comatus_naming.naming_reasons.length)
    assert_equal(@cc_macro_reason, @coprinus_comatus_naming.naming_reasons.first)
    assert_equal(3, @coprinus_comatus_naming.vote_sum)
    assert_equal(2, @coprinus_comatus_naming.votes.length)
    #
    # Check new naming.
    assert_equal(@coprinus_comatus_obs, naming.observation)
    assert_equal(@conocybe_filaris, naming.name)
    assert_equal(@rolf, naming.user)
    assert_equal(1, naming.naming_reasons.length)
    assert_equal(nr, naming.naming_reasons.first)
    assert_equal(@cc_macro_reason.reason, nr.reason)
    assert_equal(@cc_macro_reason.notes, nr.notes)
    assert_equal(2, naming.vote_sum)
    assert_equal(1, naming.votes.length)
    assert_equal(vote, naming.votes.first)
    assert_equal(2, vote.value)
    assert_equal(@rolf, vote.user)
  end

  def test_show_votes
    # First just make sure the page displays.
    params = { :id => @coprinus_comatus_naming.id }
    get(:show_votes, params)
    assert_response :success
    assert_template 'show_votes'
    #
    # Now try to make somewhat sure the content is right.
    table = @coprinus_comatus_naming.calc_vote_table
    str1 = Vote.agreement(@coprinus_comatus_owner_vote.value)
    str2 = Vote.agreement(@coprinus_comatus_other_vote.value)
    for str in table.keys
      if str == str1 && str1 == str2
        assert_equal(2, table[str][:num])
        assert(table[str][:users].member?(@rolf))
        assert(table[str][:users].member?(@mary))
      elsif str == str1
        assert_equal(1, table[str][:num])
        assert(table[str][:users].member?(@rolf))
      elsif str == str2
        assert_equal(1, table[str][:num])
        assert(table[str][:users].member?(@mary))
      else
        assert_equal(0, table[str][:num])
      end
    end
  end
end
