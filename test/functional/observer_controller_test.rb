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
  fixtures :users
  fixtures :comments
  fixtures :images
  fixtures :images_observations
  fixtures :species_lists
  fixtures :observations_species_lists
  fixtures :names
  fixtures :rss_logs

  def setup
    @controller = ObserverController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    FileUtils.cp_r(IMG_DIR.gsub(/test$/, 'setup'), IMG_DIR)
  end

  def teardown
    FileUtils.rm_rf(IMG_DIR)
  end
  
  def test_index
    get :index
    assert_response :success
    assert_template 'list_rss_logs'
  end

  def test_ask_webmaster_question
    get :ask_webmaster_question
    assert_response :success
    assert_template 'ask_webmaster_question'
  end

  def test_color_themes
    get :color_themes
    assert_response :success
    assert_template 'color_themes'
  end

  def test_how_to_use
    get :how_to_use
    assert_response :success
    assert_template 'how_to_use'
  end

  def test_images_by_title
    get :images_by_title
    assert_response :success
    assert_template 'images_by_title'
  end

  def test_intro
    get :intro
    assert_response :success
    assert_template 'intro'
  end

  def test_list_comments
    get :list_comments
    assert_response :success
    assert_template 'list_comments'
  end

  def test_list_images
    get :list_images
    assert_response :success
    assert_template 'list_images'
  end

  def test_list_observations
    get :list_observations
    assert_response :success
    assert_template 'list_observations'
  end

  def test_list_rss_logs
    get :list_rss_logs
    assert_response :success
    assert_template 'list_rss_logs'
  end

  def test_list_species_lists
    get :list_species_lists
    assert_response :success
    assert_template 'list_species_lists'
  end

  def test_name_index
    get :name_index
    assert_response :success
    assert_template 'name_index'
  end

  def test_news
    get :news
    assert_response :success
    assert_template 'news'
  end

  def test_next_image
    get :next_image
    assert_redirected_to(:controller => "observer", :action => "show_image")
  end

  def test_next_observation
    @request.session['observation_ids'] = [1, 2, 3]
    get :next_observation, :id => 1
    assert_redirected_to(:controller => "observer", :action => "show_observation", :id => 2)
  end

  def test_observations_by_name
    get :observations_by_name
    assert_response :success
    assert_template 'list_observations'
  end

  def test_pattern_search
    get :pattern_search
    assert_response :success
    assert_template 'list_observations'
  end

  def test_prev_image
    get :prev_image
    assert_redirected_to(:controller => "observer", :action => "show_image")
  end

  def test_prev_observation
    @request.session['observation_ids'] = [1, 2, 3]
    get :prev_observation, :id => 1
    assert_redirected_to(:controller => "observer", :action => "show_observation", :id => 3)
  end

  def test_rss
    get :rss
    assert_response :success
    assert_template 'rss'
  end

  def test_send_webmaster_question
    post :send_webmaster_question, "user" => {"email" => "rolf@mushroomobserver.org"}, "question" => {"content" => "Some content"}
    assert_redirected_to(:controller => "observer", :action => "list_rss_logs")

    post :send_webmaster_question, "user" => {"email" => ""}, "question" => {"content" => "Some content"}
    assert_equal("You must provide a return address.", flash[:notice])
    assert_redirected_to(:controller => "observer", :action => "ask_webmaster_question")

    post :send_webmaster_question, "user" => {"email" => "spam@spam.spam"}, "question" => {"content" => "Buy <a href='http://junk'>Me!</a>"}
    assert_equal("To cut down on robot spam, questions from unregistered users cannot contain 'http:'.", flash[:notice])
    assert_redirected_to(:controller => "observer", :action => "ask_webmaster_question")
  end

  def test_show_comment
    get :show_comment, :id => 1
    assert_response :success
    assert_template 'show_comment'
  end

  def test_show_image
    get :show_image, :id => 1
    assert_response :success
    assert_template 'show_image'
  end

  def test_show_name
    get :show_name, :id => 1
    assert_response :success
    assert_template 'show_name'
  end

  def test_show_observation
    get :show_observation, :id => 1
    assert_response :success
    assert_template 'show_observation'
  end

  def test_show_original
    get :show_original, :id => 1
    assert_response :success
    assert_template 'show_original'
  end

  def test_show_past_name
    get :show_past_name, :id => 1
    assert_response :success
    assert_template 'show_past_name'
  end

  def test_show_rss_log
    get :show_rss_log, :id => 1
    assert_response :success
    assert_template 'show_rss_log'
  end

  def test_show_species_list
    get :show_species_list, :id => 1
    assert_response :success
    assert_template 'show_species_list'
  end

  def test_species_lists_by_title
    get :species_lists_by_title
    assert_response :success
    assert_template 'species_lists_by_title'
  end
  
  def test_show_past_name
    get :show_past_name, :id => 1
    assert_response :success
    assert_template 'show_past_name'
  end

  # Pages that require login
  def login(user='rolf', password='testpassword')
    get :news 
    user = User.authenticate(user, password)
    assert(user)
    session['user'] = user
  end
  
  def requires_login(page, params={}, stay_on_page=true, user='rolf', password='testpassword')
    get(page, params)
    assert_redirected_to(:controller => "account", :action => "login")
    user = User.authenticate(user, password)
    assert(user)
    session['user'] = user
    get(page, params)
    if stay_on_page
      assert_response :success
      assert_template page.to_s
    end
  end
  
  def requires_user(page, alt_page, params={}, stay_on_page=true, username='rolf', password='testpassword')
    alt_username = 'mary'
    if username == 'mary':
      alt_username = 'rolf'
    end
    get(page, params)
    assert_redirected_to(:controller => "account", :action => "login")
    user = User.authenticate(alt_username, 'testpassword')
    assert(user)
    session['user'] = user
    get(page, params)
    assert_template alt_page.to_s
    
    login username, password
    get(page, params)
    if stay_on_page
      assert_response :success
      assert_template page.to_s
    end
  end
  
  def test_add_comment
    requires_login :add_comment, {:id => 1}
  end
  
  def test_add_image
    requires_login :add_image, {:id => @coprinus_comatus_obs.id}
    
    # Check that image cannot be added to an observation the user doesn't own
    get :add_image, :id => @minimal_unknown.id
    assert_response :success
    assert_template "show_observation"
  end

  # Test reusing an image by id number.
  def test_add_image_to_obs
    obs = @coprinus_comatus_obs
    image = @disconnected_coprinus_comatus_image
    assert(!obs.images.member?(image))
    requires_login(:add_image_to_obs, { "obs_id" => obs.id, "id" => image.id }, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs2 = Observation.find(obs.id) # Need to reload observation to pick up changes
    assert(obs2.images.member?(image))
  end
  
  def test_add_observation_to_species_list
    sp = @first_species_list
    obs = @coprinus_comatus_obs
    assert(!sp.observations.member?(obs))
    requires_login(:add_observation_to_species_list, { "species_list" => sp.id, "observation" => obs.id }, false)
    assert_redirected_to(:controller => "observer", :action => "manage_species_lists")
    sp2 = SpeciesList.find(sp.id)
    assert(sp2.observations.member?(obs))
  end
  
  def test_ask_question
    requires_login :ask_question, {:id => @coprinus_comatus_obs.id}
  end

  def test_commercial_inquiry
    requires_login :commercial_inquiry, {:id => @in_situ.id}
  end

  def test_construct_observation_simple
    # Test a simple observation creation
    count = Observation.find(:all).length
    where = "test_construct_observation_simple"
    params = {
      :observation => {
        :what => "Coprinus comatus",
        :where => where,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "9",
        :specimen => "0"
      }
    }
    requires_login(:construct_observation, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert((count + 1) == Observation.find(:all).length)
    obs = assigns(:observation)
    assert_equal(where, obs.where) # Make sure it's the right observation
    assert_not_nil(obs.rss_log)
  end
  
  def test_construct_observation_new_name
    # Test a simple observation creation
    count = Observation.find(:all).length
    params = {
      :observation => {
        :what => "New name",
        :where => "test_construct_observation_new_name",
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "9",
        :specimen => "0"
      }
    }
    requires_login(:construct_observation, params, false)
    assert_redirected_to(:controller => "observer", :action => "create_observation")
    assert(count == Observation.find(:all).length) # Should not have added a new observation
  end
  
  def test_construct_observation_approved_new_name
    # Test a simple observation creation
    count = Observation.find(:all).length
    new_name = "New name"
    params = {
      :observation => {
        :what => new_name,
        :where => "test_construct_observation_approved_new_name",
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "9",
        :specimen => "0"
      },
      :approved_name => new_name,
    }
    requires_login(:construct_observation, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert((count + 1) == Observation.find(:all).length)
  end

  def test_construct_observation_multiple_match
    # Test a simple observation creation
    count = Observation.find(:all).length
    params = {
      :observation => {
        :what => "Amanita baccata",
        :where => "test_construct_observation_multiple_match",
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "9",
        :specimen => "0"
      }
    }
    requires_login(:construct_observation, params, false)
    assert_redirected_to(:controller => "observer", :action => "create_observation")
    assert(count == Observation.find(:all).length) # Should not have added a new observation
  end

  def test_construct_observation_chosen_multiple_match
    # Test a simple observation creation
    count = Observation.find(:all).length
    params = {
      :observation => {
        :what => "Amanita baccata",
        :where => "test_construct_observation_chosen_multiple_match",
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "9",
        :specimen => "0"
      },
      :chosen_name => { :name_id => @amanita_baccata_arora.id }
    }
    requires_login(:construct_observation, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert((count + 1) == Observation.find(:all).length)
  end

  def test_construct_species_list
    params = {
      :list => { :members => "Coprinus comatus"}, # Could be a new name or an ambiguous name
      :checklist_data => {}, # Could have data in it
      :member => { :notes => "" },
      :species_list => {
        :where => "Burbank, California",
        :title => "List Title",
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes" },
      :names_only => { :first => "false" }} # Could be "true"

    requires_login(:construct_species_list, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_species_list")
  end

  def test_create_observation
    requires_login :create_observation
  end
  
  def test_create_observation_unknown_name
    params = {
      :args => {
        :what => "Easter bunny",
        :where => "Laguna Beach, California",
        "when(1i)" => "2007",
        "when(2i)" => "4",
        "when(3i)" => "1",
        :notes => "Some notes",
        :specimen => "1"
      },
    }
    requires_login(:create_observation, params)
  end
  
  def test_create_observation_multiple_names
    params = {
      :args => {
        :what => "Amanita baccata",
        :where => "Laguna Beach, California",
        "when(1i)" => "2007",
        "when(2i)" => "4",
        "when(3i)" => "1",
        :notes => "Some notes",
        :specimen => "1"
      },
      :name_ids => [@amanita_baccata_arora.id, @amanita_baccata_borealis.id]
    }
    requires_login(:create_observation, params)
  end

  def test_create_species_list
    requires_login :create_species_list
  end
  
  def test_delete_images
    obs = @detailed_unknown
    image = @turned_over
    assert(obs.images.member?(image))
    selected = {}
    for i in obs.images
      selected[i.id.to_s] = "no"
    end
    selected[image.id.to_s] = "yes"
    params = {"observation"=>{"id"=>obs.id.to_s}, "selected"=>selected}
    requires_login(:delete_images, params, false, "mary")
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs2 = Observation.find(obs.id) # Need to reload observation to pick up changes
    assert(!obs2.images.member?(image))
  end
  
  def test_destroy_comment
    comment = @minimal_comment
    obs = comment.observation
    assert(obs.comments.member?(comment))
    params = {"id"=>comment.id.to_s}
    assert("rolf" == comment.user.login)
    requires_user(:destroy_comment, :show_comment, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs = Observation.find(obs.id) # Need to reload observation to pick up changes
    assert(!obs.comments.member?(comment))
  end
  
  def test_destroy_image
    image = @turned_over
    obs = image.observations[0]
    assert(obs.images.member?(image))
    params = {"id"=>image.id.to_s}
    assert("mary" == image.user.login)
    requires_user(:destroy_image, :show_image, params, false, "mary")
    assert_redirected_to(:controller => "observer", :action => "list_images")
    obs = Observation.find(obs.id) # Need to reload observation to pick up changes
    assert(!obs.images.member?(image))
  end
  
  def test_destroy_observation
    obs = @minimal_unknown
    assert(obs)
    id = obs.id
    params = {"id"=>id.to_s}
    assert("mary" == obs.user.login)
    requires_user(:destroy_observation, :show_observation, params, false, "mary")
    assert_redirected_to(:controller => "observer", :action => "list_observations")
    assert_raises(ActiveRecord::RecordNotFound) do
      obs = Observation.find(id) # Need to reload observation to pick up changes
    end
  end
  
  def test_destroy_species_list
    spl = @first_species_list
    assert(spl)
    id = spl.id
    params = {"id"=>id.to_s}
    assert("rolf" == spl.user.login)
    requires_user(:destroy_species_list, :show_species_list, params, false)
    assert_redirected_to(:controller => "observer", :action => "list_species_lists")
    assert_raises(ActiveRecord::RecordNotFound) do
      spl = SpeciesList.find(id) # Need to reload observation to pick up changes
    end
  end

  def test_edit_comment
    comment = @minimal_comment
    params = { "id" => comment.id.to_s }
    assert("rolf" == comment.user.login)
    requires_user(:edit_comment, :show_comment, params)
  end

  def test_edit_image
    image = @connected_coprinus_comatus_image
    params = { "id" => image.id.to_s }
    assert("rolf" == image.user.login)
    requires_user(:edit_image, :show_image, params)
  end

  def test_edit_name
    name = @coprinus_comatus
    params = { "id" => name.id.to_s }
    requires_login(:edit_name, params)
  end

  def test_edit_observation
    obs = @coprinus_comatus_obs
    assert("rolf" == obs.user.login)
    params = { :id => obs.id.to_s }
    requires_user(:edit_observation, :show_observation, params)
  end
  
  def test_edit_observation_unknown_name
    obs = @coprinus_comatus_obs
    assert("rolf" == obs.user.login)
    params = {
      :id => obs.id.to_s,
      :args => {
        :what => "Easter bunny",
        :where => obs.where,
        :when => obs.when,
        :notes => obs.notes,
        :specimen => obs.specimen
      }
    }
    requires_user(:edit_observation, :show_observation, params)
  end
  
  def test_edit_observation_multiple_names
    obs = @coprinus_comatus_obs
    assert("rolf" == obs.user.login)
    params = {
      :id => obs.id.to_s,
      :args => {
        :what => "Amanita baccata",
        :where => "Laguna Beach, California",
        "when(1i)" => "2007",
        "when(2i)" => "4",
        "when(3i)" => "1",
        :notes => "Some notes",
        :specimen => "1"
      },
      :name_ids => [@amanita_baccata_arora.id, @amanita_baccata_borealis.id]
    }
    requires_user(:edit_observation, :show_observation, params)
  end
  
  def test_update_observation
    obs = @detailed_unknown
    modified = obs.rss_log.modified
    where = "test_update_observation"
    params = {
      :id => obs.id.to_s,
      :observation => {
        :what => obs.what,
        :where => where,
        :when => obs.when,
        :notes => obs.notes,
        :specimen => obs.specimen
      },
      :log_change => { :checked => '1' }
    }
    requires_user(:update_observation, :show_observation, params, false, "mary")
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs = assigns(:observation)
    assert_equal(where, obs.where)
    assert_not_equal(modified, obs.rss_log.modified)
  end

  def test_update_observation_no_logging
    obs = @detailed_unknown
    modified = obs.rss_log.modified
    where = "test_update_observation_no_logging"
    params = {
      :id => obs.id.to_s,
      :observation => {
        :what => obs.what,
        :where => where,
        :when => obs.when,
        :notes => obs.notes,
        :specimen => obs.specimen
      },
      :log_change => { :checked => '0' }
    }
    requires_user(:update_observation, :show_observation, params, false, "mary")
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs = assigns(:observation)
    assert_equal(where, obs.where)
    assert_equal(modified, obs.rss_log.modified)
  end

  def test_update_observation_new_name
    obs = @coprinus_comatus_obs
    what = obs.what
    new_name = "Easter bunny"
    params = {
      :id => obs.id.to_s,
      :observation => {
        :what => new_name,
        :where => obs.where,
        :when => obs.when,
        :notes => obs.notes,
        :specimen => obs.specimen
      },
      :log_change => { :checked => '1' }
    }
    requires_user(:update_observation, :show_observation, params, false)
    assert_redirected_to(:controller => "observer", :action => "edit_observation")
    obs = assigns(:observation)
    assert_not_equal(new_name, obs.what)
    assert_equal(what, obs.what)
    assert_nil(obs.rss_log)
  end

  def test_update_observation_approved_new_name
    obs = @coprinus_comatus_obs
    what = obs.what
    new_name = "Easter bunny"
    params = {
      :id => obs.id.to_s,
      :observation => {
        :what => new_name,
        :where => obs.where,
        :when => obs.when,
        :notes => obs.notes,
        :specimen => obs.specimen
      },
      :approved_name => new_name,
      :log_change => { :checked => '1' }
    }
    requires_user(:update_observation, :show_observation, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs = assigns(:observation)
    assert_equal(new_name, obs.what)
    assert_not_equal(what, obs.what)
    assert_not_nil(obs.rss_log)
  end

  def test_update_observation_multiple_match
    obs = @coprinus_comatus_obs
    what = obs.what
    new_name = "Amanita baccata"
    params = {
      :id => obs.id.to_s,
      :observation => {
        :what => new_name,
        :where => obs.where,
        :when => obs.when,
        :notes => obs.notes,
        :specimen => obs.specimen
      },
      :log_change => { :checked => '1' }
    }
    requires_user(:update_observation, :show_observation, params, false)
    assert_redirected_to(:controller => "observer", :action => "edit_observation")
    obs = assigns(:observation)
    assert_not_equal(new_name, obs.what)
    assert_equal(what, obs.what)
    assert_nil(obs.rss_log)
  end

  def test_update_observation_chosen_multiple_match
    obs = @coprinus_comatus_obs
    what = obs.what
    new_name = "Amanita baccata"
    params = {
      :id => obs.id.to_s,
      :observation => {
        :what => new_name,
        :where => obs.where,
        :when => obs.when,
        :notes => obs.notes,
        :specimen => obs.specimen
      },
      :chosen_name => { :name_id => @amanita_baccata_arora.id },
      :log_change => { :checked => '1' }
    }
    requires_user(:update_observation, :show_observation, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs = assigns(:observation)
    assert_equal(new_name, obs.what)
    assert_not_equal(what, obs.what)
    assert_not_nil(obs.rss_log)
  end

  def test_edit_species_list
    spl = @first_species_list
    params = { "id" => spl.id.to_s }
    assert("rolf" == spl.user.login)
    requires_user(:edit_species_list, :show_species_list, params, false)
    assert_response :success
    assert_template "edit_species_list"
  end

  def test_email_features
    page = :email_features
    get(page)
    assert_redirected_to(:controller => "account", :action => "login")
    user = User.authenticate("rolf", "testpassword")
    assert(user)
    session['user'] = user
    get(page)
    assert_redirected_to(:controller => "observer", :action => "list_observations")
    user.id = 0 # Make user the admin
    session['user'] = user
    get(page)
    assert_response :success
    assert_template page.to_s
  end

  def test_login
    get :login
    assert_redirected_to(:controller => "account", :action => "login")
  end

  def test_manage_species_lists
    obs = @coprinus_comatus_obs
    params = { "id" => obs.id.to_s }
    requires_login :manage_species_lists, params
  end

  def test_update_image
    image = @agaricus_campestris_image
    obs = image.observations[0]
    assert(obs)
    assert(obs.rss_log.nil?)
    params = {
      "id" => image.id,
      "image" => {
        "when(1i)" => "2001",
        "copyright_holder" => "Rolf Singer",
        "when(2i)" => "5",
        "when(3i)" => "12",
        "notes" => ""
      }
    }
    requires_login :update_image, params, false
    assert_redirected_to(:controller => "observer", :action => "show_image")
    obs = Observation.find(obs.id)
    pat = "^.*: Image, %s, updated by %s\n" % [image.unique_text_name, obs.user.login]
    assert_equal(0, obs.rss_log.notes =~ Regexp.new(pat.gsub(/\(/,'\(').gsub(/\)/,'\)')))
  end

  def test_read_species_list
    # TODO: Test read_species_list with a file larger than 13K to see if it
    # gets a TempFile or a StringIO.
    spl = @first_species_list
    assert_equal(0, spl.observations.length)
    list_data = "Agaricus bisporus\r\nBoletus rubripes\r\nAmanita phalloides"
    file = StringIOPlus.new(list_data)
    file.content_type = 'text/plain'
    params = {
      "id" => spl.id,
      "species_list" => {
        "file" => file
      }
    }
    requires_login :read_species_list, params, false
    assert_redirected_to(:controller => "observer", :action => "edit_species_list")
    # Doesn't actually change list, just feeds it to edit_species_list through the session
    assert_equal(list_data, session['list_members'])
  end

  def test_remove_images
    obs = @coprinus_comatus_obs
    params = { :id => obs.id }
    assert("rolf" == obs.user.login)
    requires_user(:remove_images, :show_observation, params)
  end

  def test_remove_observation_from_species_list
    spl = @unknown_species_list
    obs = @minimal_unknown
    assert(spl.observations.member?(obs))
    params = { :species_list => spl.id, :observation => obs.id }
    owner = spl.user.login
    assert("rolf" != owner)
    
    # Try with non-owner (can't use requires_user since failure is a redirect)
    requires_login(:remove_observation_from_species_list, params, false)
    # effectively fails and gets redirected to show_species_list
    assert_redirected_to(:controller => "observer", :action => "show_species_list")
    spl = SpeciesList.find(spl.id)
    assert(spl.observations.member?(obs))
    
    login owner
    get(:remove_observation_from_species_list, params)
    assert_redirected_to(:controller => "observer", :action => "manage_species_lists")
    spl = SpeciesList.find(spl.id)
    assert(!spl.observations.member?(obs))
  end

  def test_resize_images
    requires_login :resize_images, {}, false
    assert_equal("You must be an admin to access resize_images", flash[:notice])
    assert_redirected_to(:controller => "observer", :action => "list_images")
    # How should real image files be handled?
  end

  def test_reuse_image
    obs = @agaricus_campestris_obs
    params = { :id => obs.id }
    assert("rolf" == obs.user.login)
    requires_user(:reuse_image, :show_observation, params)
  end

  def test_reuse_image_by_id
    obs = @agaricus_campestris_obs
    image = @commercial_inquiry_image
    assert(!obs.images.member?(image))
    params = { :observation => { :id => obs.id, :idstr => "3" } }
    owner = obs.user.login
    assert("mary" != owner)
    requires_login(:reuse_image_by_id, params, false, "mary")
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs = Observation.find(obs.id) # Reload Observation
    assert(!obs.images.member?(image))
    
    login owner
    get(:reuse_image_by_id, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs = Observation.find(obs.id) # Reload Observation
    assert(obs.images.member?(image))
  end

  def test_save_comment
    obs = @minimal_unknown
    comment_count = obs.comments.size
    params = {
      :comment => {
        :observation_id => obs.id,
        :summary => "A Summary",
        :comment => "Some text."
      }
    }
    requires_login :save_comment, params, false
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs = Observation.find(obs.id)
    assert(obs.comments.size == (comment_count + 1))
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
    get(page, params)
    assert_redirected_to(:controller => "account", :action => "login")
    user = User.authenticate("rolf", "testpassword")
    assert(user)
    session['user'] = user
    get(page, params)
    assert_redirected_to(:controller => "observer", :action => "list_rss_logs")
    assert_equal("Only the admin can send feature mail.", flash[:notice])
    user.id = 0 # Make user the admin
    session['user'] = user
    get(page, params)
    assert_redirected_to(:controller => "observer", :action => "users_by_name")
  end
  
  def test_send_question
    obs = @minimal_unknown
    params = {
      :id => obs.id,
      :question => {
        :content => "Testing question"
      }
    }
    requires_login :send_question, params, false
    assert_equal("Delivered question.", flash[:notice])
    assert_redirected_to(:controller => "observer", :action => "show_observation")
  end

  def test_update_comment
    comment = @minimal_comment
    params = {
      :id => comment.id,
      :comment => {
        :summary => "New Summary",
        :comment => "New text."        
      }
    }
    assert("rolf" == comment.user.login)
    requires_user(:update_comment, :show_comment, params, false)
    comment = Comment.find(comment.id)
    assert(comment.summary == "New Summary")
    assert(comment.comment == "New text.")
  end

  def test_update_name
    name = @conocybe_filaris
    assert(name.text_name == "Conocybe filaris")
    assert(name.author.nil?)
    past_names = name.past_names.size
    assert(0 == name.version)
    params = {
      :id => name.id,
      :name => {
        :text_name => name.text_name,
        :author => "(Fr.) Kühner",
        :rank => :Species,
        :notes => ""
      }
    }
    requires_login(:update_name, params, false)
    name = Name.find(name.id)
    assert(name.author == "(Fr.) Kühner")
    assert(name.display_name == "__Conocybe filaris__ (Fr.) Kühner")
    assert(name.observation_name == "__Conocybe filaris__ (Fr.) Kühner")
    assert(name.search_name == "Conocybe filaris (Fr.) Kühner")
    assert(name.user == @rolf)
  end

  def test_update_species_list
    spl = @unknown_species_list
    sp_count = spl.observations.size
    params = {
      :id => spl.id,
      :list => { :members => "Coprinus comatus" }, # Could be a new name or an ambiguous name
      :checklist_data => {}, # Could have data in it
      :member => { :notes => "" },
      :species_list => {
        :where => "New Place",
        :title => "New Title",
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "New notes."
      },
      :names_only => { :first => "false" } # Could be "true"
    }
    owner = spl.user.login
    assert("rolf" != owner)
    requires_login(:update_species_list, params, false)
    assert_redirected_to(:controller => "observer", :action => "list_species_lists")
    spl = SpeciesList.find(spl.id)
    assert(spl.observations.size == sp_count)
    login owner
    get(:update_species_list, params)
    assert_redirected_to(:controller => "observer", :action => "show_species_list")
    spl = SpeciesList.find(spl.id)
    assert(spl.observations.size == (sp_count + 1))
    assert(spl.where == "New Place")
    assert(spl.title == "New Title")
    assert(spl.notes == "New notes.")
  end

  def test_upload_image
    obs = @coprinus_comatus_obs
    img_count = obs.images.size
    file = FilePlus.new("test/fixtures/images/Coprinus_comatus.jpg")
    file.content_type = 'image/jpeg'
    params = {
      :observation => {
        :id => obs.id
      },
      :image => {
        "when(1i)" => "2007",
        "when(2i)"=>"3",
        "when(3i)"=>"29",
        :copyright_holder => "Douglas Smith",
        :notes => "Some notes."
      },
      :upload => {
        :image1 => file,
        :image2 => '',
        :image3 => '',
        :image4 => ''
      }
    }
    requires_user(:upload_image, :show_observation, params, false)
    assert_redirected_to(:controller => 'observer', :action => 'show_observation')
    obs = Observation.find(obs.id)
    assert(obs.images.size == (img_count + 1))
  end

  def test_upload_species_list
    spl = @first_species_list
    params = {
      :id => spl.id
    }
    requires_user(:upload_species_list, :show_species_list, params)
  end

  def test_users_by_name
    page = :users_by_name
    get(page)
    assert_redirected_to(:controller => "account", :action => "login")
    user = User.authenticate("rolf", "testpassword")
    assert(user)
    session['user'] = user
    get(page)
    assert_redirected_to(:controller => "observer", :action => "list_observations")
    user.id = 0 # Make user the admin
    session['user'] = user
    get(page)
    assert_response :success
    assert_template page.to_s
  end
end
  

class StillToCome
  # Add reverify test
  # Add test with theme = ''
end
