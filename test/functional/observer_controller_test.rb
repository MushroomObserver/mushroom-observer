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
  fixtures :notifications
  fixtures :search_states
  fixtures :sequence_states

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
    assert_link_in_html :app_intro.t, :action => 'intro'
    assert_link_in_html :app_create_account.t, :controller => 'account', :action => 'signup'
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

  def test_how_to_help
    get_with_dump :how_to_help
    assert_response :success
    assert_template 'how_to_help'
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
    # Uses default observation query
    get_with_dump :next_observation, :id => 2
    id = SequenceState.find(:all).last.id
    assert_redirected_to(:controller => "observer", :action => "show_observation",
      :id => 1, :search_seq => nil, :seq_key => id)
  end

  def test_prev_observation
    # Uses default observation query
    get_with_dump :prev_observation, :id => 2
    id = SequenceState.find(:all).last.id
    assert_redirected_to(:controller => "observer", :action => "show_observation",
      :id => 3, :search_seq => nil, :seq_key => id)
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
    get_with_dump :pattern_search, {:commit => :app_images_find.l, :search => {:pattern => "34"}}
    assert_redirected_to(:controller => "image", :action => "image_search")
    assert_equal("34", @request.session[:pattern])
    get_with_dump :pattern_search, {:commit => :app_names_find.l, :search => {:pattern => "56"}}
    assert_redirected_to(:controller => "name", :action => "name_search")
    assert_equal("56", @request.session[:pattern])
    get_with_dump :pattern_search, {:commit => :app_locations_find.l, :search => {:pattern => "78"}}
    assert_redirected_to(:controller => "location", :action => "list_place_names", :pattern => "78")
  end

  def test_observation_search
    @request.session[:pattern] = "12"
    get_with_dump :observation_search
    assert_response :success
    assert_template 'list_observations'
    assert_equal :list_observations_matching.t(:pattern => '12'), @controller.instance_variable_get('@title')
    get_with_dump :observation_search, { :page => 2 }
    assert_response :success
    assert_template 'list_observations'
    assert_equal :list_observations_matching.t(:pattern => '12'), @controller.instance_variable_get('@title')
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
    assert_equal(:ask_webmaster_need_address.t, flash[:test_notice])
    assert_response :success

    flash[:notice] = nil
    post :ask_webmaster_question, "user" => {"email" => "spammer"}, "question" => {"content" => "Some content"}
    assert_equal(:ask_webmaster_need_address.t, flash[:test_notice])
    assert_response :success

    flash[:notice] = nil
    post :ask_webmaster_question, "user" => {"email" => "forgot@content"}, "question" => {"content" => ""}
    assert_equal(:ask_webmaster_need_content.t, flash[:test_notice])
    assert_response :success

    flash[:notice] = nil
    post :ask_webmaster_question, "user" => {"email" => "spam@spam.spam"}, "question" => {"content" => "Buy <a href='http://junk'>Me!</a>"}
    assert_equal(:ask_webmaster_antispam.t, flash[:test_notice])
    assert_response :success
  end

  def test_show_observation
    get_with_dump :show_observation, :id => @coprinus_comatus_obs.id
    assert_response :success
    assert_template 'show_observation'
    obs = @coprinus_comatus_obs.id
    seq = SequenceState.find(:all).last.id
    assert_form_action(:action => 'show_observation', :id => obs, :obs => obs, :seq_key => seq)
  end

  def test_show_observation_no_naming
    get_with_dump :show_observation, :id => @unknown_with_no_naming.id
    assert_response :success
    assert_template 'show_observation'
    obs = @unknown_with_no_naming.id
    seq = SequenceState.find(:all).last.id
    assert_form_action(:action => 'show_observation', :id => obs, :obs => obs, :seq_key => seq)
  end

  # Test a naming owned by the observer but the observer has 'No Opinion'.
  # This is a regression test for a bug in _show_namings.rhtml
  def test_show_observation_no_opinion
    # login as rolf
    user = User.authenticate("rolf", "testpassword")
    assert(user)
    @request.session[:user_id] = user.id

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
    session[:user_id] = user.id
    get(page) # Expect redirect
    assert_redirected_to(:controller => "observer", :action => "list_observations")
    user.id = 0 # Make user the admin
    session[:user_id] = user.id
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
    session[:user_id] = user.id
    get(page, params) # Expect redirect
    assert_redirected_to(:controller => "observer", :action => "list_rss_logs")
    assert_equal(:send_feature_email_denied.t, flash[:notice])
    user.id = 0 # Make user the admin
    session[:user_id] = user.id
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
    assert_equal(:ask_observation_question_success.t, flash[:notice])
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
    assert_equal(:ask_user_question_success.t, flash[:notice])
    assert_redirected_to(:controller => "observer", :action => "show_user")
  end

  def test_users_by_name
    page = :users_by_name
    get(page) # Expect redirect
    assert_redirected_to(:controller => "account", :action => "login")
    user = User.authenticate("rolf", "testpassword")
    assert(user)
    session[:user_id] = user.id
    get(page) # Exepct redirect
    assert_redirected_to(:controller => "observer", :action => "list_observations")
    user.id = 0 # Make user the admin
    session[:user_id] = user.id
    get_with_dump(page)
    assert_response :success
    assert_template page.to_s
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
  def generic_construct_observation(params, observation_count, naming_count, name_count, page=nil)
    o_count = Observation.find(:all).length
    g_count = Naming.find(:all).length
    n_count = Name.find(:all).length
    params[:observation] = {}                   if !params[:observation]
    params[:observation][:where] = "right here" if !params[:observation][:where]
    params[:observation]["when(1i)"] = "2007"
    params[:observation]["when(2i)"] = "3"
    params[:observation]["when(3i)"] = "9"
    params[:observation][:specimen]  = "0"
    params[:observation][:thumb_image_id] = "0" if !params[:observation][:thumb_image_id]
    params[:vote] = {}          if !params[:vote]
    params[:vote][:value] = "3" if !params[:vote][:value]
    post_requires_login(:create_observation, params, false)
    if observation_count == 1
      if page != :notest
        assert_redirected_to(:controller => "observer", :action => (page || "show_observation"))
      end
    else
      assert_response(:success)
    end
    assert_equal((o_count + observation_count), Observation.find(:all).length)
    assert_equal((g_count + naming_count), Naming.find(:all).length)
    assert_equal((n_count + name_count), Name.find(:all).length)
    assert_equal(10+observation_count+2*naming_count+10*name_count, @rolf.reload.contribution)
    if observation_count == 1
      assert_not_equal(0, @controller.instance_variable_get('@observation').thumb_image_id)
    end
  end

  def test_construct_observation_simple
    # Test a simple observation creation with an approved unique name
    where = "test_construct_observation_simple"
    generic_construct_observation({
      :observation => { :where => where, :thumb_image_id => '0' },
      :name => { :name => "Coprinus comatus" }
    }, 1,1,0)
    obs = assigns(:observation)
    nam = assigns(:naming)
    assert_equal(where, obs.where) # Make sure it's the right observation
    assert_equal(@coprinus_comatus.id, nam.name_id) # Make sure it's the right name
    assert_equal("2.03659", "%.5f" % obs.vote_cache)
    assert_not_nil(obs.rss_log)
    # This was getting set to zero instead of nil if no images were uploaded when obs was created.
    assert_equal(nil, obs.thumb_image_id)
  end

  def test_construct_observation_unknown
    # Test a simple observation creation of an unknown
    where = "test_construct_observation_unknown"
    generic_construct_observation({
      :observation => { :where => where },
      :name => { :name => "Unknown" }
    }, 1,0,0)
    obs = assigns(:observation)
    assert_equal(where, obs.where) # Make sure it's the right observation
    assert_not_nil(obs.rss_log)
  end

  def test_construct_observation_new_name
    # Test an observation creation with a new name
    generic_construct_observation({
      :name => { :name => "New name" }
    }, 0,0,0)
  end

  def test_construct_observation_approved_new_name
    # Test an observation creation with an approved new name
    new_name = "Argus arg-arg"
    generic_construct_observation({
      :name => { :name => new_name },
      :approved_name => new_name
    }, 1,1,2)
  end

  def test_construct_observation_approved_section
    # Test an observation creation with an approved section (should fail)
    new_name = "Argus section Argus"
    generic_construct_observation({
      :name => { :name => new_name },
      :approved_name => new_name
    }, 0,0,0)
  end

  def test_construct_observation_approved_junk
    # Test an observation creation with an approved junk name
    new_name = "This is a bunch of junk"
    generic_construct_observation({
      :name => { :name => new_name },
      :approved_name => new_name
    }, 0,0,0)
  end

  def test_construct_observation_multiple_match
    # Test an observation creation with multiple matches
    generic_construct_observation({
      :name => { :name => "Amanita baccata" }
    }, 0,0,0)
  end

  def test_construct_observation_chosen_multiple_match
    # Test an observation creation with one of the multiple matches chosen
    generic_construct_observation({
      :name => { :name => "Amanita baccata" },
      :chosen_name => { :name_id => @amanita_baccata_arora.id }
    }, 1,1,0)
  end

  def test_construct_observation_deprecated_multiple_match
    # Test an observation creation with one of the multiple matches chosen
    generic_construct_observation({
      :name => { :name => @pluteus_petasatus_deprecated.text_name }
    }, 1,1,0)
    nam = assigns(:naming)
    assert_equal(@pluteus_petasatus_approved.id, nam.name_id)
  end

  def test_construct_observation_deprecated
    # Test an observation creation with a deprecated name
    generic_construct_observation({
      :name => { :name => "Lactarius subalpinus" }
    }, 0,0,0)
  end

  def test_construct_observation_chosen_deprecated
    # Test an observation creation with a deprecated name, but a chosen approved alternative
    new_name = "Lactarius subalpinus"
    generic_construct_observation({
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
    generic_construct_observation({
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
    generic_construct_observation({
      :name => { :name => new_name },
      :approved_name => new_name
    }, 1,1,1)
    name = Name.find_by_text_name(new_name)
    assert(name)
    assert_equal(new_name, name.text_name)
  end

  def test_construct_observation_with_notification
    count_before = QueuedEmail.find(:all).length
    name = @agaricus_campestris
    notifications = Notification.find_all_by_flavor_and_obj_id(:name, name.id)
    assert_equal(2, notifications.length)

    where = "test_construct_observation_simple"
    generic_construct_observation({
      :observation => { :where => where },
      :name => { :name => name.text_name }
    }, 1,1,0, 'show_notifications')
    obs = assigns(:observation)
    nam = assigns(:naming)
    assert_equal(where, obs.where) # Make sure it's the right observation
    assert_equal(name.id, nam.name_id) # Make sure it's the right name
    assert_not_nil(obs.rss_log)

    count_after = QueuedEmail.find(:all).length
    assert_equal(count_before+2, count_after)
  end

  # This is no longer necessary as it will add the author immediately now without confirmation. [JPH -20080227]
  # def test_construct_observation_approved_new_author
  #   # Test an observation creation with an approved new name
  #   name = @strobilurus_diminutivus_no_author
  #   assert_nil(name.author)
  #   author = 'Desjardin'
  #   new_name = "#{name.text_name} #{author}"
  #   generic_construct_observation({
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
        :specimen => new_specimen,
        :thumb_image_id => "0",
      },
      :log_change => { :checked => '1' }
    }
    post_requires_user(:edit_observation, ["observer", "show_observation"], params, false, "mary")
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal(10, @rolf.reload.contribution)
    obs = assigns(:observation)
    assert_equal(new_where, obs.where)
    assert_equal("2001-02-03", obs.when.to_s)
    assert_equal(new_notes, obs.notes)
    assert_equal(new_specimen, obs.specimen)
    assert_not_equal(modified, obs.rss_log.modified)
    assert_not_equal(0, obs.thumb_image_id)
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
    assert_equal(10, @rolf.reload.contribution)
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
    assert_equal(10, @rolf.reload.contribution)
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
      :approved_name => new_name,
      :vote => { :value => 1 }
    }
    post_requires_user(:edit_naming, ["observer", "show_observation"], params, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    # Clones naming, creates Easter sp and E. bunny, but no votes.
    assert_equal(32, @rolf.reload.contribution)
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
    assert_equal(10, @rolf.reload.contribution)
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
      :chosen_name => { :name_id => @amanita_baccata_arora.id },
      :vote => { :value => 1 }
    }
    post_requires_user(:edit_naming, ["observer", "show_observation"], params, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    # Must be cloning naming with no vote.
    assert_equal(12, @rolf.reload.contribution)
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
    assert_equal(10, @rolf.reload.contribution)
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
      :chosen_name => { :name_id => chosen_name.id },
      :vote => { :value => 1 }
    }
    post_requires_user(:edit_naming, ["observer", "show_observation"], params, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    # Must be cloning naming, with no vote.
    assert_equal(12, @rolf.reload.contribution)
    nam = assigns(:naming)
    assert_not_equal(start_name.id, nam.name_id)
    assert_equal(chosen_name.id, nam.name_id)
  end

  def test_update_observation_accepted_deprecated
    nam = @coprinus_comatus_naming
    start_name = nam.name
    new_text_name = @lactarius_subalpinus.text_name
    params = {
      :id => nam.id.to_s,
      :name => { :name => new_text_name },
      :approved_name => new_text_name,
      :chosen_name => { },
      :vote => { :value => 3 },
    }
    post_requires_user(:edit_naming, ["observer", "show_observation"], params, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    # Must be cloning the naming, but no votes?
    assert_equal(12, @rolf.reload.contribution)
    nam = assigns(:naming)
    assert_not_equal(start_name.id, nam.name_id)
    assert_equal(new_text_name, nam.name.text_name)
  end

  def test_name_resolution
    params = {
      :observation => {
        :when => Time.now,
        :where => 'somewhere',
        :specimen => '0',
        :thumb_image_id => '0',
      },
      :name => {},
      :vote => { :value => "3" },
    }
    @request.session[:user_id] = 1

    # Can we create observation with existing genus?
    # -----------------------------------------------
    params[:name][:name] = 'Agaricus'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal(@agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = 'Agaricus sp'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal(@agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = 'Agaricus sp.'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal(@agaricus.id, assigns(:observation).name_id)

    # Can we create observation with genus and add author?
    # -----------------------------------------------------
    params[:name][:name] = 'Agaricus Author'
    params[:approved_name] = 'Agaricus Author'
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal(@agaricus.id, assigns(:observation).name_id)
    assert_equal('Agaricus sp. Author', @agaricus.reload.search_name)
    @agaricus.author = nil
    @agaricus.search_name = 'Agaricus sp.'
    @agaricus.save

    params[:name][:name] = 'Agaricus sp Author'
    params[:approved_name] = 'Agaricus sp Author'
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal(@agaricus.id, assigns(:observation).name_id)
    assert_equal('Agaricus sp. Author', @agaricus.reload.search_name)
    @agaricus.author = nil
    @agaricus.search_name = 'Agaricus sp.'
    @agaricus.save

    params[:name][:name] = 'Agaricus sp. Author'
    params[:approved_name] = 'Agaricus sp. Author'
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal(@agaricus.id, assigns(:observation).name_id)
    assert_equal('Agaricus sp. Author', @agaricus.reload.search_name)

    # Can we create observation with genus specifying author?
    # --------------------------------------------------------
    params[:name][:name] = 'Agaricus Author'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal(@agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = 'Agaricus sp Author'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal(@agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = 'Agaricus sp. Author'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal(@agaricus.id, assigns(:observation).name_id)

    # Can we create observation with deprecated genus?
    # -------------------------------------------------
    params[:name][:name] = 'Psalliota'
    params[:approved_name] = 'Psalliota'
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal(@psalliota.id, assigns(:observation).name_id)

    params[:name][:name] = 'Psalliota sp'
    params[:approved_name] = 'Psalliota sp'
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal(@psalliota.id, assigns(:observation).name_id)

    params[:name][:name] = 'Psalliota sp.'
    params[:approved_name] = 'Psalliota sp.'
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal(@psalliota.id, assigns(:observation).name_id)

    # Can we create observation with deprecated genus, adding author?
    # ----------------------------------------------------------------
    params[:name][:name] = 'Psalliota Author'
    params[:approved_name] = 'Psalliota Author'
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal(@psalliota.id, assigns(:observation).name_id)
    assert_equal('Psalliota sp. Author', @psalliota.reload.search_name)
    @psalliota.author = nil
    @psalliota.search_name = 'Psalliota sp.'
    @psalliota.save

    params[:name][:name] = 'Psalliota sp Author'
    params[:approved_name] = 'Psalliota sp Author'
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal(@psalliota.id, assigns(:observation).name_id)
    assert_equal('Psalliota sp. Author', @psalliota.reload.search_name)
    @psalliota.author = nil
    @psalliota.search_name = 'Psalliota sp.'
    @psalliota.save

    params[:name][:name] = 'Psalliota sp. Author'
    params[:approved_name] = 'Psalliota sp. Author'
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal(@psalliota.id, assigns(:observation).name_id)
    assert_equal('Psalliota sp. Author', @psalliota.reload.search_name)

    # Can we create new quoted genus?
    # --------------------------------
    params[:name][:name] = '"One"'
    params[:approved_name] = '"One"'
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One" sp.', assigns(:observation).name.search_name)

    params[:name][:name] = '"Two" sp'
    params[:approved_name] = '"Two" sp'
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal('"Two"', assigns(:observation).name.text_name)
    assert_equal('"Two" sp.', assigns(:observation).name.search_name)

    params[:name][:name] = '"Three" sp.'
    params[:approved_name] = '"Three" sp.'
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal('"Three"', assigns(:observation).name.text_name)
    assert_equal('"Three" sp.', assigns(:observation).name.search_name)

    params[:name][:name] = '"One"'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal('"One"', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" sp'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal('"One"', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" sp.'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal('"One"', assigns(:observation).name.text_name)

    # Can we create species under the quoted genus?
    # ----------------------------------------------
    params[:name][:name] = '"One" foo'
    params[:approved_name] = '"One" foo'
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal('"One" foo', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" "bar"'
    params[:approved_name] = '"One" "bar"'
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal('"One" "bar"', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" Author'
    params[:approved_name] = '"One" Author'
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One" sp. Author', assigns(:observation).name.search_name)

    params[:name][:name] = '"One" sp Author'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One" sp. Author', assigns(:observation).name.search_name)

    params[:name][:name] = '"One" sp. Author'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One" sp. Author', assigns(:observation).name.search_name)
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
    assert_equal(@coprinus_comatus.id, @coprinus_comatus_obs.name_id)
    assert(@coprinus_comatus_naming.user_voted?(@rolf))
    assert(@coprinus_comatus_naming.user_voted?(@mary))
    assert(!@coprinus_comatus_naming.user_voted?(@dick))
    assert(@coprinus_comatus_other_naming.user_voted?(@rolf))
    assert(@coprinus_comatus_other_naming.user_voted?(@mary))
    assert(!@coprinus_comatus_other_naming.user_voted?(@dick))
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
    # Make sure contribution is updated correctly.
    assert_equal(12, @rolf.reload.contribution)
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
    assert_equal(@agaricus.id, @coprinus_comatus_obs.name_id)
    #
    # Make sure naming was created correctly and referenced.
    assert_equal(@coprinus_comatus_obs, naming.observation)
    assert_equal(@agaricus.id, naming.name_id)
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
    assert_equal(12, @rolf.reload.contribution)
    #
    # Make sure everything I need is reloaded.
    @coprinus_comatus_obs.reload
    @coprinus_comatus_naming.reload
    #
    # Get new objects.
    naming = Naming.find(:all).last
    #
    # Make sure observation was updated right.
    assert_equal(@coprinus_comatus.id, @coprinus_comatus_obs.name_id)
    #
    # Make sure preferred_namings are right.
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
    assert_equal(12, @dick.reload.contribution)
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
    assert_equal(@conocybe_filaris.id, @coprinus_comatus_obs.name_id)
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
    assert_redirected_to(:controller => "observer", :action => "show_observation", :id => @coprinus_comatus_obs.id)
    assert_equal(12, @dick.reload.contribution)
    naming = Naming.find(:all).last
    assert_equal("Conocybe filaris", naming.name.text_name)
    assert_equal("(With) Author", naming.name.author)
    assert_equal(@conocybe_filaris.id, naming.name_id)
  end

  # Test a bug in name resolution: was failing to recognize that
  # "Genus species (With) Author" was recognized even if "Genus species"
  # was already in the database.
  def test_create_naming_fill_in_author
    params = {
      :id => @coprinus_comatus_obs.id,
      :name => { :name => 'Agaricus campestris' },
    }
    post_requires_login(:create_naming, params, false, "dick")
    assert_equal('Agaricus campestris L.', @controller.instance_variable_get('@what'))
  end

  # Test a bug in name resolution: was failing to recognize that
  # "Genus species (With) Author" was recognized even if "Genus species"
  # was already in the database.
  def test_create_name_with_quotes
    name = 'Foo "bar" Author'
    params = {
      :id => @coprinus_comatus_obs.id,
      :name => { :name => name },
      :approved_name => name
    }
    post_requires_login(:create_naming, params, false, "dick")
    assert(name = Name.find_by_text_name('Foo "bar"'))
    assert_equal('Foo "bar" Author', name.search_name)
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
    assert_equal(11, @dick.reload.contribution)
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
    assert_equal(@coprinus_comatus.id, @coprinus_comatus_obs.name_id)
    #
    # If Dick votes on the other as well, then his first vote should
    # get demoted and his preference should change.
    # Summing, 3 gets 2+1+3/4=1.5, 9 gets -3+3+2/4=.5, so 3 keeps it.
    @coprinus_comatus_naming.change_vote(@dick, 3)
    assert_equal(12, @dick.reload.contribution)
    @coprinus_comatus_obs.reload
    @coprinus_comatus_naming.reload
    @coprinus_comatus_other_naming.reload
    assert_equal(3, @coprinus_comatus_naming.users_vote(@dick).value)
    assert_equal(6, @coprinus_comatus_naming.vote_sum)
    assert_equal(3, @coprinus_comatus_naming.votes.length)
    assert_equal(2, @coprinus_comatus_other_naming.users_vote(@dick).value)
    assert_equal(2, @coprinus_comatus_other_naming.vote_sum)
    assert_equal(3, @coprinus_comatus_other_naming.votes.length)
    assert_equal(@coprinus_comatus.id, @coprinus_comatus_obs.name_id)
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
    assert_equal(10, @rolf.reload.contribution)
    #
    # Make sure everything I need is reloaded.
    @coprinus_comatus_obs.reload
    @coprinus_comatus_naming.reload
    @coprinus_comatus_other_naming.reload
    #
    # Make sure observation was updated right.
    assert_equal(@coprinus_comatus.id, @coprinus_comatus_obs.name_id)
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
    assert_equal(10, @rolf.reload.contribution)
    #
    # Make sure everything I need is reloaded.
    @coprinus_comatus_obs.reload
    @coprinus_comatus_naming.reload
    @coprinus_comatus_other_naming.reload
    #
    # Make sure observation was updated right.
    assert_equal(@agaricus_campestris.id, @coprinus_comatus_obs.name_id)
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
    assert_equal(10, @rolf.reload.contribution)
    #
    # Make sure everything I need is reloaded.
    @coprinus_comatus_obs.reload
    @coprinus_comatus_naming.reload
    @coprinus_comatus_other_naming.reload
    #
    # Make sure observation was updated right.
    assert_equal(@coprinus_comatus.id, @coprinus_comatus_obs.name_id)
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
    assert_equal(@coprinus_comatus.id, @coprinus_comatus_obs.name_id)
    assert_equal(11, @dick.reload.contribution)
    #
    params = {
      :vote => {
        :value     => Vote.delete_vote,
        :naming_id => @coprinus_comatus_naming.id
      }
    }
    post_requires_login(:cast_vote, params, false, "mary")
    assert_equal(9, @mary.reload.contribution)
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
    assert_equal(@coprinus_comatus.id, @coprinus_comatus_obs.name_id)
  end

  # Rolf can destroy his naming if Mary deletes her vote on it.
  def test_rolf_destroy_rolfs_naming
    # First delete Mary's vote for it.
    @coprinus_comatus_naming.change_vote(@mary, Vote.delete_vote)
    assert_equal(9, @mary.reload.contribution)
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
    assert_equal(@agaricus_campestris.id, @coprinus_comatus_obs.name_id)
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
    assert_equal(11, @dick.reload.contribution)
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
    assert_equal(@coprinus_comatus.id, @coprinus_comatus_obs.name_id)
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
    post_requires_user(:edit_naming, ['observer', 'show_observation'], params, false, "rolf")
    assert_equal(10, @rolf.reload.contribution)
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
    assert_equal(@coprinus_comatus.id, @coprinus_comatus_obs.name_id)
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
    post_requires_user(:edit_naming, ['observer', 'show_observation'], params, false, "rolf")
    assert_equal(12, @rolf.reload.contribution)
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
    assert_equal(@conocybe_filaris.id, @coprinus_comatus_obs.name_id)
    #
    # Make sure old naming is unchanged.
    assert_equal(@coprinus_comatus.id, @coprinus_comatus_naming.name_id)
    assert_equal(1, @coprinus_comatus_naming.naming_reasons.length)
    assert_equal(@cc_macro_reason, @coprinus_comatus_naming.naming_reasons.first)
    assert_equal(3, @coprinus_comatus_naming.vote_sum)
    assert_equal(2, @coprinus_comatus_naming.votes.length)
    #
    # Check new naming.
    assert_equal(@coprinus_comatus_obs, naming.observation)
    assert_equal(@conocybe_filaris.id, naming.name_id)
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
      elsif str == str1
        assert_equal(1, table[str][:num])
      elsif str == str2
        assert_equal(1, table[str][:num])
      else
        assert_equal(0, table[str][:num])
      end
    end
  end

  # -----------------------------------
  #  Test extended observation forms.
  # -----------------------------------

  def test_javascripty_name_reasons

    # If javascript isn't enabled, then checkbox isn't required.
    @request.session[:user_id] = 1
    post(:create_observation, {
      :observation => { :where => 'where', :when => Time.now },
      :name => { :name => @coprinus_comatus.text_name },
      :vote => { :value => 3 },
      :reason => {
        "1" => { :check => '0', :notes => ''    },
        "2" => { :check => '0', :notes => 'foo' },
        "3" => { :check => '1', :notes => ''    },
        "4" => { :check => '1', :notes => 'bar' }
      },
    })
    assert_response(302) # redirected = created observation successfully
    naming = Naming.find(assigns(:naming).id)
    reasons = naming.naming_reasons.map {|nr| nr.reason}.sort
    assert_equal([2,3,4], reasons)

    # If javascript IS enabled, then checkbox IS required.
    @request.session[:user_id] = 1
    post(:create_observation, {
      :observation => { :where => 'where', :when => Time.now },
      :name => { :name => @coprinus_comatus.text_name },
      :vote => { :value => 3 },
      :reason => {
        "1" => { :check => '0', :notes => ''    },
        "2" => { :check => '0', :notes => 'foo' },
        "3" => { :check => '1', :notes => ''    },
        "4" => { :check => '1', :notes => 'bar' }
      },
      :was_js_on => 'yes'
    })
    assert_response(302) # redirected = created observation successfully
    naming = Naming.find(assigns(:naming).id)
    reasons = naming.naming_reasons.map {|nr| nr.reason}.sort
    assert_equal([3,4], reasons)
  end

  def test_create_with_image_upload
    time0 = Time.utc(2000)
    time1 = Time.utc(2001)
    time2 = Time.utc(2002)
    time3 = Time.utc(2003)
    now   = 1.week.ago

    FileUtils.cp_r(IMG_DIR.gsub(/test_images$/, 'setup_images'), IMG_DIR)
    file1 = FilePlus.new("test/fixtures/images/Coprinus_comatus.jpg")
    file1.content_type = 'image/jpeg'
    file2 = FilePlus.new("test/fixtures/images/Coprinus_comatus.jpg")
    file2.content_type = 'image/jpeg'
    file3 = FilePlus.new("test/fixtures/images/Coprinus_comatus.jpg")
    file3.content_type = 'image/jpeg'

    new_image_1 = Image.new({
      :copyright_holder => 'holder_1',
      :when => time1,
      :notes => 'notes_1',
      :user_id => 1,
      :image => file1,
      :content_type => 'image/jpeg',
      :created => now,
      :modified => now,
    })
    new_image_1.save

    new_image_2 = Image.new({
      :copyright_holder => 'holder_2',
      :when => time2,
      :notes => 'notes_2',
      :user_id => 2,
      :image => file2,
      :content_type => 'image/jpeg',
      :created => now,
      :modified => now,
    })
    new_image_2.save

    @request.session[:user_id] = 1
    post(:create_observation, {
      :observation => {
        :where => 'zzyzx',
        :when => time0,
        :thumb_image_id => 0,   # (make new image the thumbnail)
        :notes => 'blah',
      },
      :image => { '0' => {
        :image => file3,
        :copyright_holder => 'holder_3',
        :when => time3,
        :notes => 'notes_3'
      }},
      # (attach these two images once observation created)
      :good_images => "#{new_image_1.id} #{new_image_2.id}",
      "image_#{new_image_1.id}_notes" => 'notes_1',
      "image_#{new_image_2.id}_notes" => 'notes_2_new',
    })
    # print flash.to_s, "\n"
    assert_response(302) # redirected = created observation successfully

    obs = Observation.find_by_where('zzyzx')
    assert_equal(1, obs.user_id)
    assert_equal(time0, obs.when)
    assert_equal('zzyzx', obs.place_name)

    imgs = obs.images.sort_by {|x| x.id}
    img_ids = imgs.map {|i| i.id}
    assert_equal([new_image_1.id, new_image_2.id, new_image_2.id+1], img_ids)
    assert_equal(new_image_2.id+1, obs.thumb_image_id)
    assert_equal('holder_1', imgs[0].copyright_holder)
    assert_equal('holder_2', imgs[1].copyright_holder)
    assert_equal('holder_3', imgs[2].copyright_holder)
    assert_equal(time1, imgs[0].when)
    assert_equal(time2, imgs[1].when)
    assert_equal(time3, imgs[2].when)
    assert_equal('notes_1',     imgs[0].notes)
    assert_equal('notes_2_new', imgs[1].notes)
    assert_equal('notes_3',     imgs[2].notes)
    assert(imgs[0].modified < 1.day.ago)
    assert(imgs[1].modified > 1.day.ago)
  end

  def test_image_upload_when_create_fails
    FileUtils.cp_r(IMG_DIR.gsub(/test_images$/, 'setup_images'), IMG_DIR)
    file = FilePlus.new("test/fixtures/images/Coprinus_comatus.jpg")
    file.content_type = 'image/jpeg'

    @request.session[:user_id] = 1
    post(:create_observation, {
      :observation => {
        :where => '',  # will cause failure
        :when => Time.now,
      },
      :image => { '0' => {
        :image => file,
        :copyright_holder => 'zuul',
        :when => Time.now,
      }},
    })
    assert_response(200) # success = failure, paradoxically
    # print flash[:notice], "\n"

    # Make sure image was created, but that it is unattached, and that it has
    # been kept in the @good_images array for attachment later.
    img = Image.find_by_copyright_holder('zuul')
    assert(img)
    assert_equal([], img.observations)
    assert([img.id], @controller.instance_variable_get('@good_images').map {|i| i.id})
  end

  # ----------------------------
  #  Interest.
  # ----------------------------

  def test_interest_in_show_observation
    # No interest in this observation yet.
    @request.session[:user_id] = @rolf.id
    get(:show_observation, { :id => @minimal_unknown.id })
    assert_response :success
    assert_link_in_html(/<img[^>]+watch\d*.png[^>]+>[\w\s]*/, {
      :controller => 'interest', :action => 'set_interest',
      :type => 'Observation', :id => @minimal_unknown.id, :state => 1
    })
    assert_link_in_html(/<img[^>]+ignore\d*.png[^>]+>[\w\s]*/, {
      :controller => 'interest', :action => 'set_interest',
      :type => 'Observation', :id => @minimal_unknown.id, :state => -1
    })

    # Turn interest on and make sure there is an icon linked to delete it.
    Interest.new(:object => @minimal_unknown, :user => @rolf, :state => true).save
    @request.session[:user_id] = @rolf.id
    get(:show_observation, { :id => @minimal_unknown.id })
    assert_response :success
    assert_link_in_html(/<img[^>]+halfopen\d*.png[^>]+>/, {
      :controller => 'interest', :action => 'set_interest',
      :type => 'Observation', :id => @minimal_unknown.id, :state => 0
    })
    assert_link_in_html(/<img[^>]+ignore\d*.png[^>]+>/, {
      :controller => 'interest', :action => 'set_interest',
      :type => 'Observation', :id => @minimal_unknown.id, :state => -1
    })

    # Destroy that interest, create new one with interest off.
    Interest.find_all_by_user_id(@rolf.id).last.destroy
    Interest.new(:object => @minimal_unknown, :user => @rolf, :state => false).save
    @request.session[:user_id] = @rolf.id
    get(:show_observation, { :id => @minimal_unknown.id })
    assert_response :success
    assert_link_in_html(/<img[^>]+halfopen\d*.png[^>]+>/, {
      :controller => 'interest', :action => 'set_interest',
      :type => 'Observation', :id => @minimal_unknown.id, :state => 0
    })
    assert_link_in_html(/<img[^>]+watch\d*.png[^>]+>/, {
      :controller => 'interest', :action => 'set_interest',
      :type => 'Observation', :id => @minimal_unknown.id, :state => 1
    })
  end
end
