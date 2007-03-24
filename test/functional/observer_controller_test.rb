require File.dirname(__FILE__) + '/../test_helper'
require 'observer_controller'
require 'fileutils'

# Re-raise errors caught by the controller.
class ObserverController; def rescue_action(e) raise e end; end

# Create a subclass of StringIO that has a content_type member
# to replicate the dynamic method addition that happens in Rails
# cgi.rb.
class StringIOPlus < StringIO
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

  def setup
    @controller = ObserverController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    FileUtils.cp_r(IMG_DIR.gsub(/test$/, 'setup'), IMG_DIR)
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

  def test_construct_observation
    log_change = {"checked"=>"1"}
    obs_params = {
      # :name_id # Could be set to clarify ambiguous names
      :what => "Coprinus comatus", # Could be unknown name to go to unknown_name_create
      :where => "Burbank, California", # Must be set to something
      "when(1i)" => "2007",
      "when(2i)" => "3",
      "when(3i)" => "9",
      :specimen => "0"
    }
    
    requires_login(:construct_observation, { "observation" => obs_params, "log_change" => log_change }, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
  end

  def test_construct_species_list
    params = {
      "list"=>{"members"=>"Coprinus comatus"}, # Could be a new name or an ambiguous name
      "checklist_data"=>{}, # Could have data in it
      "member"=>{"notes"=>""},
      "species_list"=>{
        "where"=>"Burbank, California",
        "title"=>"List Title",
        "when(1i)"=>"2007",
        "when(2i)"=>"3",
        "when(3i)"=>"14"},
        "notes"=>"List Notes",
      "names_only"=>{"first"=>"false"}} # Could be "true"

    requires_login(:construct_species_list, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_species_list")
  end

  def test_create_observation
    requires_login :create_observation
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
    owner = comment.user.login
    
    # Try as the wrong user
    assert("mary" != owner)
    requires_login(:destroy_comment, params, false, "mary")
    assert_template "show_comment"
    obs = Observation.find(obs.id)
    assert(obs.comments.member?(comment))
    
    # Try as the owner
    login owner
    post(:destroy_comment, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs = Observation.find(obs.id) # Need to reload observation to pick up changes
    assert(!obs.comments.member?(comment))
  end
  
  def test_destroy_image
    image = @turned_over
    obs = image.observations[0]
    assert(obs.images.member?(image))
    params = {"id"=>image.id.to_s}
    owner = image.user.login
    
    # Try as the wrong user
    assert("rolf" != owner)
    requires_login(:destroy_image, params, false)
    assert_template "show_image"
    obs = Observation.find(obs.id)
    assert(obs.images.member?(image))
    
    # Try as the owner
    login owner
    post(:destroy_image, params)
    assert_redirected_to(:controller => "observer", :action => "list_images")
    obs = Observation.find(obs.id) # Need to reload observation to pick up changes
    assert(!obs.images.member?(image))
  end
  
  def test_destroy_observation
    obs = @minimal_unknown
    assert(obs)
    id = obs.id
    params = {"id"=>id.to_s}
    owner = obs.user.login
    
    # Try as the wrong user
    assert("rolf" != owner)
    requires_login(:destroy_observation, params, false)
    assert_template "show_observation"
    obs = Observation.find(id)
    assert(obs)
    
    # Try as the owner
    login owner
    post(:destroy_observation, params)
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
    owner = spl.user.login
    
    # Try as the wrong user
    assert("mary" != owner)
    requires_login(:destroy_species_list, params, false, "mary")
    assert_template "show_species_list"
    spl = SpeciesList.find(id)
    assert(spl)
    
    # Try as the owner
    login owner
    post(:destroy_species_list, params)
    assert_redirected_to(:controller => "observer", :action => "list_species_lists")
    assert_raises(ActiveRecord::RecordNotFound) do
      spl = SpeciesList.find(id) # Need to reload observation to pick up changes
    end
  end

  def test_edit_comment
    comment = @minimal_comment
    params = { "id" => comment.id.to_s }
    owner = comment.user.login
    assert("mary" != owner)
    requires_login(:edit_comment, params, false, "mary")
    assert_template "show_comment"
    
    login owner
    post(:edit_comment, params)
    assert_response :success
    assert_template "edit_comment"
  end

  def test_edit_image
    image = @connected_coprinus_comatus_image
    params = { "id" => image.id.to_s }
    owner = image.user.login
    assert("mary" != owner)
    requires_login(:edit_image, params, false, "mary")
    assert_template "show_image"
    
    login owner
    post(:edit_image, params)
    assert_response :success
    assert_template "edit_image"
  end

  def test_edit_name
    name = @coprinus_comatus
    params = { "id" => name.id.to_s }
    requires_login(:edit_name, params)
  end

  def test_edit_observation
    obs = @coprinus_comatus_obs
    params = { "id" => obs.id.to_s }
    owner = obs.user.login
    assert("mary" != owner)
    requires_login(:edit_observation, params, false, "mary")
    assert_template "show_observation"
    
    login owner
    post(:edit_observation, params)
    assert_response :success
    assert_template "edit_observation"
  end

  def test_edit_species_list
    spl = @first_species_list
    params = { "id" => spl.id.to_s }
    owner = spl.user.login
    assert("mary" != owner)
    requires_login(:edit_species_list, params, false, "mary")
    assert_template "show_species_list"
    
    login owner
    post(:edit_species_list, params)
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
    assert_equal(session['list_members'], list_data)
  end

  def test_remove_images
    obs = @coprinus_comatus_obs
    params = { :id => obs.id }
    owner = obs.user.login
    assert("mary" != owner)
    requires_login :remove_images, params, false, "mary"
    assert_template "show_observation"
    
    login owner
    post(:remove_images, params)
    assert_response :success
    assert_template "remove_images"
  end

  def test_remove_observation_from_species_list
    spl = @unknown_species_list
    obs = @minimal_unknown
    assert(spl.observations.member?(obs))
    
    params = { :species_list => spl.id, :observation => obs.id }
    owner = spl.user.login
    assert("rolf" != owner)
    requires_login(:remove_observation_from_species_list, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_species_list")
    
    login owner
    get(:remove_observation_from_species_list, params)
    assert_redirected_to(:controller => "observer", :action => "manage_species_lists")
    spl = SpeciesList.find(spl.id)
    assert(!spl.observations.member?(obs))
  end

  def test_resize_images
    requires_login :resize_images, {}, false
    assert_equal(flash[:notice], "You must be an admin to access resize_images")
    assert_redirected_to(:controller => "observer", :action => "list_images")
    # How should real image files be handled?
  end

end
  

class StillToCome

  def resize_images
    if check_permission(0)
      for image in Image.find(:all)
        image.calc_size()
        image.resize_image(160, 160, image.thumbnail)
      end
    else
      flash[:notice] = "You must be an admin to access resize_images"
    end
    redirect_to :action => 'list_images'
  end

  def test_reuse_image
    requires_login :reuse_image
  end

  def test_reuse_image_by_id
    requires_login :reuse_image_by_id
  end

  def test_save_comment
    requires_login :save_comment
  end

  def test_save_image
    requires_login :save_image
  end

  def test_send_commercial_inquiry
    requires_login :send_commercial_inquiry
    assert_template 'send_commercial_inquiry'
  end

  def test_send_feature_email
    requires_login :send_feature_email
    assert_template 'send_feature_email'
  end

  def test_send_question
    requires_login :send_question
    assert_template 'send_question'
  end

  def test_test_commercial_inquiry
    requires_login :test_commercial_inquiry
  end

  def test_test_feature_email
    requires_login :test_feature_email
  end

  def test_test_question
    requires_login :test_question
  end

  def test_update_comment
    requires_login :update_comment
  end

  # Already implemented
  def test_update_image
    requires_login :update_image
  end

  def test_update_name
    requires_login :update_name
  end

  def test_update_observation
    requires_login :update_observation
  end

  def test_update_observation_with_new_name
    requires_login :update_observation_with_new_name
  end

  def test_update_observation_with_selected_name
    requires_login :update_observation_with_selected_name
  end

  def test_update_species_list
    requires_login :update_species_list
  end

  def test_upload_image
    requires_login :upload_image
  end

  def test_upload_species_list
    requires_login :upload_species_list
  end

  def test_users_by_name
    requires_login :users_by_name
  end


  # These should get integrated into construct_observation and get tested with that
  def test_construct_observation_with_new_name
    requires_login :construct_observation_with_new_name
  end

  def test_construct_observation_with_selected_name
    requires_login :construct_observation_with_selected_name
  end
  
  def test_multiple_names
    requires_login :multiple_names
  end

  def test_multiple_names_create
    requires_login :multiple_names_create
  end

  def test_unknown_name
    requires_login :unknown_name
  end

  def test_unknown_name_create
    requires_login :unknown_name_create
  end

  # Add reverify test
  # Add test with theme = ''
end
