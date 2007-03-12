require File.dirname(__FILE__) + '/../test_helper'
require 'observer_controller'

# Re-raise errors caught by the controller.
class ObserverController; def rescue_action(e) raise e end; end

class ObserverControllerTest < Test::Unit::TestCase
  fixtures :observations
  fixtures :users
  fixtures :comments
  fixtures :images
  fixtures :images_observations
  fixtures :species_lists
  fixtures :observations_species_lists

  def setup
    @controller = ObserverController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
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
    get :news # Need to load a page for session to get populated
    user = User.authenticate(user, password)
    assert(user)
    session['user'] = user
  end
  
  def requires_login(page, args={}, user='rolf', password='testpassword')
    get page, args
    assert_redirected_to(:controller => "account", :action => "login")
    user = User.authenticate(user, password)
    assert(user)
    session['user'] = user
    get page, args
    assert_response :success
    assert_template page.to_s
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
    login
    post(:add_image_to_obs, "obs_id" => obs.id, "id" => image.id)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs2 = Observation.find(obs.id) # Need to reload observation to pick up changes
    assert(obs2.images.member?(image))
  end
  
  def test_add_observation_to_species_list
    sp = @first_species_list
    obs = @coprinus_comatus_obs
    assert(!sp.observations.member?(obs))
    login
    post(:add_observation_to_species_list, "species_list" => sp.id, "observation" => obs.id)
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
    #  {"log_change"=>{"checked"=>"1"},
    #   "commit"=>"Create",
    #   "observation"=>{"where"=>"Burbank, California", "when(1i)"=>"2007", "when(2i)"=>"3", "when(3i)"=>"9",
    #                   "notes"=>"", "what"=>"Conocybe filaris", "specimen"=>"0"},
    #   "action"=>"construct_observation", "controller"=>"observer"}
    log_change = {"checked"=>"1"}
    obs_params = {}
    # obs_params[:name_id] # Could be set to clarify ambiguous names
    obs_params[:what] = "Coprinus comatus" # Could be unknown name to go to unknown_name_create
    obs_params[:where] = "Burbank, California" # Required
    obs_params["when(1i)"] = "2007"
    obs_params["when(2i)"] = "3"
    obs_params["when(3i)"] = "9"
    obs_params[:specimen] = "0"
    
    login
    post(:construct_observation, "observation" => obs_params, "log_change" => log_change)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
  end

end


class StillToCome

  def test_construct_species_list
    requires_login :construct_species_list
  end

  def test_create_species_list
    requires_login :create_species_list
  end

  # Should extend construct_observation so it works like construct_species_list
  # and deprecates construct_observation_with_new_name and construct_observation_with_selected_name
  # create_observation.rhtml -> list_observations.rhtml
  def construct_observation
    user = session['user']
    if verify_user(user)
      @observation = Observation.new(params[:observation])
      now = Time.now
      @observation.created = now
      @observation.modified = now
      @observation.user = user
      name_id = params[:observation][:name_id]
      if name_id
        names = [Name.find(name_id)]
      else
        names = Name.find_names(params[:observation][:what])
      end
      if names.length == 1
        @observation.name = names[0]
        if @observation.save
          @observation.log('Observation created by ' + session['user'].login, true)
          flash[:notice] = 'Observation was successfully created.'
          redirect_to :action => 'show_observation', :id => @observation
        else
          render :action => 'create_observation'
        end
      elsif names.length == 0
        # @observation.what has new name
        args = params[:observation]
        args[:user_id] = user.id
        session[:args] = params[:observation]
        if @observation.what == ''
          redirect_to :action => 'create_observation'
        else
          redirect_to :action => 'unknown_name_create'
        end
      else
        # @observation.what matches more than one name
        @names = names
        args = params[:observation]
        args[:user_id] = user.id
        session[:args] = params[:observation]
        flash[:notice] = 'More than one matching name was found'
        redirect_to :action => 'multiple_names_create'
      end
    end
  end

  def test_construct_observation_with_new_name
    requires_login :construct_observation_with_new_name
  end

  def test_construct_observation_with_selected_name
    requires_login :construct_observation_with_selected_name
  end

  def test_create_observation
    requires_login :create_observation
  end

  def test_current_image_state
    requires_login :current_image_state
  end

  def test_delete_images
    requires_login :delete_images
  end

  def test_destroy_comment
    requires_login :destroy_comment
  end

  def test_destroy_image
    requires_login :destroy_image
  end

  def test_destroy_observation
    requires_login :destroy_observation
  end

  def test_destroy_species_list
    requires_login :destroy_species_list
  end

  def test_do_load_test
    requires_login :do_load_test
  end

  def test_edit_comment
    requires_login :edit_comment
  end

  def test_edit_image
    requires_login :edit_image
  end

  def test_edit_name
    requires_login :edit_name
  end

  def test_edit_observation
    requires_login :edit_observation
  end

  def test_edit_species_list
    requires_login :edit_species_list
  end

  def test_email_features
    requires_login :email_features
  end

  def test_login
    requires_login :login
  end

  def test_manage_images
    requires_login :manage_images
  end

  def test_manage_species_lists
    requires_login :manage_species_lists
  end

  def test_multiple_names
    requires_login :multiple_names
  end

  def test_multiple_names_create
    requires_login :multiple_names_create
  end

  def test_read_session
    requires_login :read_session
  end

  def test_read_species_list
    requires_login :read_species_list
  end

  def test_remove_images
    requires_login :remove_images
  end

  def test_remove_observation_from_species_list
    requires_login :remove_observation_from_species_list
  end

  def test_resize_images
    requires_login :resize_images
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

  def test_unknown_name
    requires_login :unknown_name
  end

  def test_unknown_name_create
    requires_login :unknown_name_create
  end

  def test_update_comment
    requires_login :update_comment
  end

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

  # Add reverify test
  # Add test with theme = ''
end
