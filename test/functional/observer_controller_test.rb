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
  fixtures :synonyms

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

  def test_all_names
    get :all_names
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

  def test_users_by_contribution
    get :users_by_contribution
    assert_response :success
    assert_template 'users_by_contribution'
  end
  
  def test_show_past_name
    get :show_past_name, :id => 1
    assert_response :success
    assert_template 'show_past_name'
  end

  def test_show_user
    get :show_user, :id => 1
    assert_response :success
    assert_template 'show_user'
  end
  
  def test_show_user_no_id
    get :show_user
    assert_redirected_to(:controller => "observer", :action => "users_by_contribution")
  end
  
  def test_show_site_stats
    get :show_site_stats
    assert_response :success
    assert_template 'show_site_stats'
  end
  
  def test_show_user_observations
    get :show_user_observations, :id => 1
    assert_response :success
    assert_template 'list_observations'
  end
  
  def test_show_comments_for_user
    get :show_comments_for_user, :id => 1
    assert_response :success
    assert_template("list_comments")
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
    if alt_page.class == Array
      assert_redirected_to(:controller => alt_page[0], :action => alt_page[1])
    else
      assert_template alt_page.to_s
    end
    
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
    # Test a simple observation creation with a valid unique name
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
    # Test an observation creation with a new name
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
    assert_equal(count, Observation.find(:all).length) # Should not have added a new observation
  end

  def test_construct_observation_approved_new_name
    # Test an observation creation with an approved new name
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
    assert_equal((count + 1), Observation.find(:all).length)
  end

  def test_construct_observation_approved_junk
    # Test an observation creation with an approved junk name
    count = Observation.find(:all).length
    new_name = "This is a bunch of junk"
    params = {
      :observation => {
        :what => new_name,
        :where => "test_construct_observation_approved_junk",
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "9",
        :specimen => "0"
      },
      :approved_name => new_name,
    }
    requires_login(:construct_observation, params, false)
    assert_redirected_to(:controller => "observer", :action => "create_observation")
    assert_equal(count, Observation.find(:all).length)
  end

  def test_construct_observation_multiple_match
    # Test an observation creation with multiple matches
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
    # Test an observation creation with one of the multiple matches chosen
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

  def test_construct_observation_invalid
    # Test an observation creation with an invalid name
    count = Observation.find(:all).length
    params = {
      :observation => {
        :what => "Lactarius subalpinus",
        :where => "test_construct_observation_invalid",
        "when(1i)" => "2007",
        "when(2i)" => "6",
        "when(3i)" => "2",
        :specimen => "0"
      }
    }
    requires_login(:construct_observation, params, false)
    assert_redirected_to(:controller => "observer", :action => "create_observation")
    assert(count == Observation.find(:all).length) # Should not have added a new observation
  end

  def test_construct_observation_chosen_invalid
    # Test an observation creation with an invalid name, but a chosen valid alternative
    count = Observation.find(:all).length
    new_name = "Lactarius subalpinus"
    params = {
      :observation => {
        :what => new_name,
        :where => "test_construct_observation_chosen_invalid",
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "9",
        :specimen => "0"
      },
      :approved_name => new_name,
      :chosen_name => { :name_id => @lactarius_alpinus.id }
    }
    requires_login(:construct_observation, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert((count + 1) == Observation.find(:all).length)
    obs = assigns(:observation)
    assert(obs.name, @lactarius_alpinus)
  end

  def test_construct_observation_approved_invalid
    # Test an observation creation with an invalid name that has been approved
    count = Observation.find(:all).length
    new_name = "Lactarius subalpinus"
    params = {
      :observation => {
        :what => new_name,
        :where => "test_construct_observation_approved_invalid",
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "9",
        :specimen => "0"
      },
      :approved_name => new_name,
      :chosen_name => { }
    }
    requires_login(:construct_observation, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert((count + 1) == Observation.find(:all).length)
    obs = assigns(:observation)
    assert_equal(obs.name, @lactarius_subalpinus)
  end

  def test_construct_species_list
    list_title = "List Title"
    params = {
      :list => { :members => @coprinus_comatus.text_name },
      :member => { :notes => "" },
      :species_list => {
        :where => "Burbank, California",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      }
    }
    requires_login(:construct_species_list, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_species_list")
    spl = SpeciesList.find(:all, :conditions => "title = '#{list_title}'")[0]
    assert_not_nil(spl)
    assert(spl.name_included(@coprinus_comatus))
  end

  def test_construct_species_list_existing_genus
    list_title = "List Title"
    params = {
      :list => { :members => "#{@agaricus.rank} #{@agaricus.text_name}" },
      :checklist_data => {},
      :member => { :notes => "" },
      :species_list => {
        :where => "Burbank, California",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      }
    }
    requires_login(:construct_species_list, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_species_list")
    spl = SpeciesList.find(:all, :conditions => "title = '#{list_title}'")[0]
    assert_not_nil(spl)
    assert(spl.name_included(@agaricus))
  end

  def test_construct_species_list_new_family
    list_title = "List Title"
    rank = :Family
    new_name_str = "Agaricaceae"
    new_list_str = "#{rank} #{new_name_str}"
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_name_str]))
    params = {
      :list => { :members => new_list_str },
      :checklist_data => {},
      :member => { :notes => "" },
      :species_list => {
        :where => "Burbank, California",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      },
      :approved_names => [new_name_str]
    }
    requires_login(:construct_species_list, params, false)
    # print "\n#{flash[:notice]}\n"
    assert_redirected_to(:controller => "observer", :action => "show_species_list")
    spl = SpeciesList.find(:all, :conditions => "title = '#{list_title}'")[0]
    assert_not_nil(spl)
    new_name = Name.find(:first, :conditions => ["text_name = ?", new_name_str])
    assert_not_nil(new_name)
    assert_equal(rank, new_name.rank)
    assert(spl.name_included(new_name))
  end

  def test_update_bulk_names_nn_synonym
    new_name_str = "Amanita fergusonii"
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_name_str]))
    new_synonym_str = "Amanita lanei"
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_synonym_str]))
    params = {
      :list => { :members => "#{new_name_str} = #{new_synonym_str}"},
    }
    requires_login(:update_bulk_names, params, false)
    assert_redirected_to(:controller => "observer", :action => "bulk_name_edit")
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_name_str]))
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_synonym_str]))
  end

  def test_update_bulk_names_approved_nn_synonym
    new_name_str = "Amanita fergusonii"
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_name_str]))
    new_synonym_str = "Amanita lanei"
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_synonym_str]))
    params = {
      :list => { :members => "#{new_name_str} = #{new_synonym_str}"},
      :approved_names => [new_name_str, new_synonym_str]
    }
    requires_login(:update_bulk_names, params, false)
    assert_redirected_to(:controller => "observer", :action => "all_names")
    new_name = Name.find(:first, :conditions => ["text_name = ?", new_name_str])
    assert(new_name)
    assert(!new_name.deprecated)
    assert_equal(:Species, new_name.rank)
    synonym_name = Name.find(:first, :conditions => ["text_name = ?", new_synonym_str])
    assert(synonym_name)
    assert(synonym_name.deprecated)
    assert_equal(:Species, synonym_name.rank)
    assert_not_nil(new_name.synonym)
    assert_equal(new_name.synonym, synonym_name.synonym)
  end

  def test_update_bulk_names_ee_synonym
    valid_name = @chlorophyllum_rachodes
    synonym_name = @macrolepiota_rachodes
    assert_not_equal(valid_name.synonym, synonym_name.synonym)
    assert(!synonym_name.deprecated)
    params = {
      :list => { :members => "#{valid_name.search_name} = #{synonym_name.search_name}"},
    }
    requires_login(:update_bulk_names, params, false)
    # print "\n#{flash[:notice]}\n"
    assert_redirected_to(:controller => "observer", :action => "all_names")
    valid_name = Name.find(valid_name.id)
    assert(!valid_name.deprecated)
    synonym_name = Name.find(synonym_name.id)
    assert(synonym_name.deprecated)
    assert_not_nil(valid_name.synonym)
    assert_equal(valid_name.synonym, synonym_name.synonym)
  end

  def test_update_bulk_names_eee_synonym
    valid_name = @lepiota_rachodes
    synonym_name = @lepiota_rhacodes
    assert_nil(valid_name.synonym)
    assert_nil(synonym_name.synonym)
    assert(!synonym_name.deprecated)
    synonym_name2 = @chlorophyllum_rachodes
    assert_not_nil(synonym_name2.synonym)
    assert(!synonym_name2.deprecated)
    params = {
      :list => { :members => ("#{valid_name.search_name} = #{synonym_name.search_name}\r\n" +
                              "#{valid_name.search_name} = #{synonym_name2.search_name}")},
    }
    requires_login(:update_bulk_names, params, false)
    # print "\n#{flash[:notice]}\n"
    assert_redirected_to(:controller => "observer", :action => "all_names")
    valid_name = Name.find(valid_name.id)
    assert(!valid_name.deprecated)
    synonym_name = Name.find(synonym_name.id)
    assert(synonym_name.deprecated)
    assert_not_nil(valid_name.synonym)
    assert_equal(valid_name.synonym, synonym_name.synonym)
    synonym_name2 = Name.find(synonym_name2.id)
    assert(synonym_name.deprecated)
    assert_equal(valid_name.synonym, synonym_name2.synonym)
  end

  def test_update_bulk_names_en_synonym
    valid_name = @chlorophyllum_rachodes
    target_synonym = valid_name.synonym
    assert(target_synonym)
    new_synonym_str = "New name Wilson"
    assert_nil(Name.find(:first, :conditions => ["search_name = ?", new_synonym_str]))
    params = {
      :list => { :members => "#{valid_name.search_name} = #{new_synonym_str}"},
      :approved_names => [valid_name.search_name, new_synonym_str]
    }
    requires_login(:update_bulk_names, params, false)
    assert_redirected_to(:controller => "observer", :action => "all_names")
    valid_name = Name.find(valid_name.id)
    assert(!valid_name.deprecated)
    synonym_name = Name.find(:first, :conditions => ["search_name = ?", new_synonym_str])
    assert(synonym_name)
    assert(synonym_name.deprecated)
    assert_equal(:Species, synonym_name.rank)
    assert_not_nil(valid_name.synonym)
    assert_equal(valid_name.synonym, synonym_name.synonym)
    assert_equal(target_synonym, valid_name.synonym)
  end

  def test_update_bulk_names_ne_synonym
    new_name_str = "New name Wilson"
    assert_nil(Name.find(:first, :conditions => ["search_name = ?", new_name_str]))
    synonym_name = @macrolepiota_rachodes
    assert(!synonym_name.deprecated)
    target_synonym = synonym_name.synonym
    assert(target_synonym)
    params = {
      :list => { :members => "#{new_name_str} = #{synonym_name.search_name}"},
      :approved_names => [new_name_str, synonym_name.search_name]
    }
    requires_login(:update_bulk_names, params, false)
    assert_redirected_to(:controller => "observer", :action => "all_names")
    valid_name = Name.find(:first, :conditions => ["search_name = ?", new_name_str])
    assert(valid_name)
    assert(!valid_name.deprecated)
    assert_equal(:Species, valid_name.rank)
    synonym_name = Name.find(synonym_name.id)
    assert(synonym_name.deprecated)
    assert_not_nil(valid_name.synonym)
    assert_equal(valid_name.synonym, synonym_name.synonym)
    assert_equal(target_synonym, valid_name.synonym)
  end

  # <name> = <name> shouldn't work in construct_species_list
  def test_construct_species_list_synonym
    list_title = "List Title"
    name = @macrolepiota_rachodes
    synonym_name = @lepiota_rachodes
    assert(!synonym_name.deprecated)
    assert_nil(synonym_name.synonym)
    params = {
      :list => { :members => "#{name.text_name} = #{synonym_name.text_name}"},
      :checklist_data => {},
      :member => { :notes => "" },
      :species_list => {
        :where => "Burbank, California",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      },
    }
    requires_login(:construct_species_list, params, false)
    # print "\n#{flash[:notice]}\n"
    assert_redirected_to(:controller => "observer", :action => "create_species_list")
    synonym_name = Name.find(synonym_name.id)
    assert(!synonym_name.deprecated)
    assert_nil(synonym_name.synonym)
  end

  def test_construct_species_list_junk
    list_title = "List Title"
    new_name_str = "This is a bunch of junk"
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_name_str]))
    params = {
      :list => { :members => new_name_str },
      :checklist_data => {},
      :member => { :notes => "" },
      :species_list => {
        :where => "Burbank, California",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      },
      :approved_names => [new_name_str]
    }
    requires_login(:construct_species_list, params, false)
    # print "\n#{flash[:notice]}\n"
    assert_redirected_to(:controller => "observer", :action => "create_species_list")
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_name_str]))
    assert_equal([], SpeciesList.find(:all, :conditions => "title = '#{list_title}'"))
  end

  def test_construct_species_list_rankless_taxon
    list_title = "List Title"
    new_name_str = "Agaricaceae"
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_name_str]))
    params = {
      :list => { :members => new_name_str },
      :checklist_data => {},
      :member => { :notes => "" },
      :species_list => {
        :where => "Burbank, California",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "3",
        "when(3i)" => "14",
        :notes => "List Notes"
      },
      :approved_names => [new_name_str]
    }
    requires_login(:construct_species_list, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_species_list")
    spl = SpeciesList.find(:all, :conditions => "title = '#{list_title}'")[0]
    assert_not_nil(spl)
    new_name = Name.find(:first, :conditions => ["text_name = ?", new_name_str])
    assert_not_nil(new_name)
    assert_equal(:Genus, new_name.rank)
    assert(spl.name_included(new_name))
  end

  # Rather than repeat everything done for update_species, this construct species just
  # does a bit of everything.
  def test_construct_species_list_extravaganza
    deprecated_name = @lactarius_subalpinus
    list_members = [deprecated_name.text_name]
    multiple_name = @amanita_baccata_arora
    list_members.push(multiple_name.text_name)
    new_name_str = "New name"
    list_members.push(new_name_str)
    assert_nil(Name.find(:first, :conditions => "text_name = '#{new_name_str}'"))

    checklist_data = {}
    current_checklist_name = @agaricus_campestris
    checklist_data[current_checklist_name.id.to_s] = "checked"
    deprecated_checklist_name = @lactarius_alpigenes
    valid_name = @lactarius_alpinus
    checklist_data[deprecated_checklist_name.id.to_s] = "checked"

    list_title = "List Title"
    params = {
      :list => { :members => list_members.join("\r\n") },
      :checklist_data => checklist_data,
      :member => { :notes => "" },
      :species_list => {
        :where => "Burbank, California",
        :title => list_title,
        "when(1i)" => "2007",
        "when(2i)" => "6",
        "when(3i)" => "4",
        :notes => "List Notes"
      },
    }
    params[:approved_names] = [new_name_str]
    params[:chosen_names] = { multiple_name.text_name => multiple_name.id.to_s }
    params[:approved_deprecated_names] = [deprecated_name.text_name, deprecated_checklist_name.search_name]
    params[:chosen_valid_names] = { deprecated_checklist_name.search_name => valid_name.id.to_s }

    requires_login(:construct_species_list, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_species_list")
    spl = SpeciesList.find(:all, :conditions => "title = '#{list_title}'")[0]
    assert(spl.name_included(deprecated_name))
    assert(spl.name_included(multiple_name))
    assert(spl.name_included(Name.find(:first, :conditions => "text_name = '#{new_name_str}'")))
    assert(spl.name_included(current_checklist_name))
    assert(!spl.name_included(deprecated_checklist_name))
    assert(spl.name_included(valid_name))
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

  def test_bulk_name_edit_list
    requires_login :bulk_name_edit
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
    assert(!obs.name.deprecated)
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

  def test_update_observation_invalid
    obs = @coprinus_comatus_obs
    what = obs.what
    new_name = "Lactarius subalpinus"
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

  def test_update_observation_chosen_invalid
    obs = @coprinus_comatus_obs
    start_name = obs.name
    new_name = "Lactarius subalpinus"
    chosen_name = @lactarius_alpinus
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
      :chosen_name => { :name_id => chosen_name.id },
      :log_change => { :checked => '1' }
    }
    requires_user(:update_observation, :show_observation, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs = assigns(:observation)
    assert_not_equal(start_name, obs.name)
    assert_equal(chosen_name, obs.name)
    assert_not_nil(obs.rss_log)
  end

  def test_update_observation_accepted_invalid
    obs = @coprinus_comatus_obs
    start_name = obs.name
    new_text_name = @lactarius_subalpinus.text_name
    params = {
      :id => obs.id.to_s,
      :observation => {
        :what => new_text_name,
        :where => obs.where,
        :when => obs.when,
        :notes => obs.notes,
        :specimen => obs.specimen
      },
      :approved_name => new_text_name,
      :chosen_name => { },
      :log_change => { :checked => '1' }
    }
    requires_user(:update_observation, :show_observation, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs = assigns(:observation)
    assert_not_equal(start_name, obs.name)
    assert_equal(new_text_name, obs.name.text_name)
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
    assert_equal("(Fr.) Kühner", name.author)
    assert_equal("__Conocybe filaris__ (Fr.) Kühner", name.display_name)
    assert_equal("__Conocybe filaris__ (Fr.) Kühner", name.observation_name)
    assert_equal("Conocybe filaris (Fr.) Kühner", name.search_name)
    assert_equal(@rolf, name.user)
  end

  def test_update_name_simple_merge
    misspelt_name = @agaricus_campestrus
    correct_name = @agaricus_campestris
    assert_not_equal(misspelt_name, correct_name)
    past_names = correct_name.past_names.size
    assert(0 == correct_name.version)
    assert_equal(1, misspelt_name.observations.size)
    misspelt_obs_id = misspelt_name.observations[0].id
    assert_equal(1, correct_name.observations.size)
    correct_obs_id = correct_name.observations[0].id

    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => @agaricus_campestris.text_name,
        :author => "",
        :rank => :Species,
        :notes => ""
      }
    }
    requires_login(:update_name, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(misspelt_name.id)
    end
    correct_name = Name.find(correct_name.id)
    assert(correct_name)
    assert(1 == correct_name.version)
    assert(past_names+1 == correct_name.past_names.size)
    
    assert_equal(2, correct_name.observations.size)
    misspelt_obs = Observation.find(misspelt_obs_id)
    assert_equal(@agaricus_campestris, misspelt_obs.name)
    correct_obs = Observation.find(correct_obs_id)
    assert_equal(@agaricus_campestris, correct_obs.name)
  end

  def test_update_name_author_merge
    misspelt_name = @amanita_baccata_borealis
    correct_name = @amanita_baccata_arora
    assert_not_equal(misspelt_name, correct_name)
    assert_equal(misspelt_name.text_name, correct_name.text_name)
    correct_author = correct_name.author
    assert_not_equal(misspelt_name.author, correct_author)
    past_names = correct_name.past_names.size
    assert(0 == correct_name.version)
    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => misspelt_name.text_name,
        :author => correct_name.author,
        :rank => :Species,
        :notes => ""
      }
    }
    requires_login(:update_name, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(misspelt_name.id)
    end
    correct_name = Name.find(correct_name.id)
    assert(correct_name)
    assert_equal(correct_author, correct_name.author)
    assert(1 == correct_name.version)
    assert(past_names+1 == correct_name.past_names.size)
  end

  # Test that merged names end up as not deprecated if the
  # correct name is not deprecated.
  def test_update_name_deprecated_merge
    misspelt_name = @lactarius_alpigenes
    assert(misspelt_name.deprecated)
    correct_name = @lactarius_alpinus
    assert(!correct_name.deprecated)
    assert_not_equal(misspelt_name, correct_name)
    assert_not_equal(misspelt_name.text_name, correct_name.text_name)
    correct_author = correct_name.author
    assert_not_equal(misspelt_name.author, correct_author)
    past_names = correct_name.past_names.size
    assert(0 == correct_name.version)
    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => correct_name.text_name,
        :author => correct_name.author,
        :rank => :Species,
        :notes => ""
      }
    }
    requires_login(:update_name, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(misspelt_name.id)
    end
    correct_name = Name.find(correct_name.id)
    assert(correct_name)
    assert(!correct_name.deprecated)
    assert_equal(correct_author, correct_name.author)
    assert(1 == correct_name.version)
    assert(past_names+1 == correct_name.past_names.size)
  end

  # Test that merged names end up as not deprecated even if the
  # correct name is deprecated but the misspelt name is not deprecated
  def test_update_name_deprecated2_merge
    misspelt_name = @lactarius_alpinus
    assert(!misspelt_name.deprecated)
    correct_name = @lactarius_alpigenes
    assert(correct_name.deprecated)
    assert_not_equal(misspelt_name, correct_name)
    assert_not_equal(misspelt_name.text_name, correct_name.text_name)
    correct_author = correct_name.author
    correct_text_name = correct_name.text_name
    assert_not_equal(misspelt_name.author, correct_author)
    past_names = correct_name.past_names.size
    assert(0 == correct_name.version)
    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => correct_name.text_name,
        :author => correct_name.author,
        :rank => :Species,
        :notes => ""
      }
    }
    requires_login(:update_name, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      correct_name = Name.find(correct_name.id)
    end
    misspelt_name = Name.find(misspelt_name.id)
    assert(misspelt_name)
    assert(!misspelt_name.deprecated)
    assert_equal(correct_author, misspelt_name.author)
    assert_equal(correct_text_name, misspelt_name.text_name)
    assert(1 == misspelt_name.version)
    assert(past_names+1 == misspelt_name.past_names.size)
  end

  def test_update_name_page_unmergeable
    misspelt_name = @agaricus_campestras
    correct_name = @agaricus_campestris
    correct_text_name = correct_name.text_name
    correct_author = correct_name.author
    assert_not_equal(misspelt_name, correct_name)
    past_names = correct_name.past_names.size
    assert(0 == correct_name.version)
    assert_equal(1, misspelt_name.observations.size)
    misspelt_obs_id = misspelt_name.observations[0].id
    assert_equal(1, correct_name.observations.size)
    correct_obs_id = correct_name.observations[0].id

    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => correct_text_name,
        :author => "",
        :rank => :Species,
        :notes => ""
      }
    }
    requires_login(:update_name, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")
    # Because misspelt name is unmergable it gets reused and
    # corrected rather than the correct name
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(correct_name.id)
    end
    correct_name = Name.find(misspelt_name.id)
    assert(correct_name)
    assert(1 == correct_name.version)
    assert(past_names+1 == correct_name.past_names.size)
  
    assert_equal(2, correct_name.observations.size)
    misspelt_obs = Observation.find(misspelt_obs_id)
    assert_equal(@agaricus_campestras, misspelt_obs.name)
    correct_obs = Observation.find(correct_obs_id)
    assert_equal(@agaricus_campestras, correct_obs.name)
  end

  def test_update_name_other_unmergeable
    misspelt_name = @agaricus_campestrus
    correct_name = @agaricus_campestras
    correct_text_name = correct_name.text_name
    correct_author = correct_name.author
    assert_not_equal(misspelt_name, correct_name)
    past_names = correct_name.past_names.size
    assert(0 == correct_name.version)
    assert_equal(1, misspelt_name.observations.size)
    misspelt_obs_id = misspelt_name.observations[0].id
    assert_equal(1, correct_name.observations.size)
    correct_obs_id = correct_name.observations[0].id

    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => correct_text_name,
        :author => "",
        :rank => :Species,
        :notes => ""
      }
    }
    requires_login(:update_name, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(misspelt_name.id)
    end
    correct_name = Name.find(correct_name.id)
    assert(correct_name)
    assert(1 == correct_name.version)
    assert(past_names+1 == correct_name.past_names.size)
  
    assert_equal(2, correct_name.observations.size)
    misspelt_obs = Observation.find(misspelt_obs_id)
    assert_equal(@agaricus_campestras, misspelt_obs.name)
    correct_obs = Observation.find(correct_obs_id)
    assert_equal(@agaricus_campestras, correct_obs.name)
  end

  def test_update_name_neither_mergeable
    misspelt_name = @agaricus_campestros
    correct_name = @agaricus_campestras
    correct_text_name = correct_name.text_name
    correct_author = correct_name.author
    assert_not_equal(misspelt_name, correct_name)
    past_names = correct_name.past_names.size
    assert(0 == correct_name.version)
    assert_equal(1, misspelt_name.observations.size)
    misspelt_obs_id = misspelt_name.observations[0].id
    assert_equal(1, correct_name.observations.size)
    correct_obs_id = correct_name.observations[0].id

    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => correct_text_name,
        :author => "",
        :rank => :Species,
        :notes => ""
      }
    }
    requires_login(:update_name, params, false)
    assert_redirected_to(:controller => "observer", :action => "edit_name")
    misspelt_name = Name.find(misspelt_name.id)
    assert(misspelt_name)
    correct_name = Name.find(correct_name.id)
    assert(correct_name)
    assert(0 == correct_name.version)
    assert(past_names == correct_name.past_names.size)
    assert_equal(1, correct_name.observations.size)
    assert_equal(1, misspelt_name.observations.size)
    assert_not_equal(correct_name.observations[0], misspelt_name.observations[0])
  end

  def test_update_name_page_version_merge
    page_name = @coprinellus_micaceus
    other_name = @coprinellus_micaceus_no_author
    assert(page_name.version > other_name.version)
    assert_not_equal(page_name, other_name)
    assert_equal(page_name.text_name, other_name.text_name)
    correct_author = page_name.author
    assert_not_equal(other_name.author, correct_author)
    past_names = page_name.past_names.size
    params = {
      :id => page_name.id,
      :name => {
        :text_name => page_name.text_name,
        :author => '',
        :rank => :Species,
        :notes => ""
      }
    }
    requires_login(:update_name, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      destroyed_name = Name.find(other_name.id)
    end
    merge_name = Name.find(page_name.id)
    assert(merge_name)
    assert_equal(correct_author, merge_name.author)
    assert_equal(past_names+1, merge_name.version)
  end

  def test_update_name_other_version_merge
    page_name = @coprinellus_micaceus_no_author
    other_name = @coprinellus_micaceus
    assert(page_name.version < other_name.version)
    assert_not_equal(page_name, other_name)
    assert_equal(page_name.text_name, other_name.text_name)
    correct_author = other_name.author
    assert_not_equal(page_name.author, correct_author)
    past_names = other_name.past_names.size
    params = {
      :id => page_name.id,
      :name => {
        :text_name => page_name.text_name,
        :author => '',
        :rank => :Species,
        :notes => ""
      }
    }
    requires_login(:update_name, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      destroyed_name = Name.find(page_name.id)
    end
    merge_name = Name.find(other_name.id)
    assert(merge_name)
    assert_equal(correct_author, merge_name.author)
    assert_equal(past_names+1, merge_name.version)
  end

  def spl_params(spl)
    params = {
      :id => spl.id,
      :species_list => {
        :where => spl.where,
        :title => spl.title,
        "when(1i)" => spl.when.year.to_s,
        "when(2i)" => spl.when.month.to_s,
        "when(3i)" => spl.when.day.to_s,
        :notes => spl.notes
      },
      :list => { :members => "" },
      :checklist_data => {},
      :member => { :notes => "" },
    }
  end
  
  def test_update_species_list_nochange
    spl = @unknown_species_list
    sp_count = spl.observations.size
    params = spl_params(spl)
    requires_user(:update_species_list, ["observer", "list_species_lists"], params, false, spl.user.login)
    assert_redirected_to(:controller => "observer", :action => "show_species_list")
    spl = SpeciesList.find(spl.id)
    assert_equal(sp_count, spl.observations.size)
  end

  def test_update_species_list_text_add
    spl = @unknown_species_list
    sp_count = spl.observations.size
    params = spl_params(spl)
    params[:list][:members] = "Coprinus comatus"
    params[:species_list][:where] = "New Place"
    params[:species_list][:title] = "New Title"
    params[:species_list][:notes] = "New notes."
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
    assert_equal(sp_count + 1, spl.observations.size)
    assert_equal("New Place", spl.where)
    assert_equal("New Title", spl.title)
    assert_equal("New notes.", spl.notes)
  end
  
  def test_update_species_list_new_name
    spl = @unknown_species_list
    sp_count = spl.observations.size
    params = spl_params(spl)
    params[:list][:members] = "New name"
    requires_user(:update_species_list, ["observer", "list_species_lists"], params, false, spl.user.login)
    assert_redirected_to(:controller => "observer", :action => "edit_species_list")
    spl = SpeciesList.find(spl.id)
    assert_equal(sp_count, spl.observations.size)
  end
  
  def test_update_species_list_approved_new_name
    spl = @unknown_species_list
    sp_count = spl.observations.size
    params = spl_params(spl)
    params[:list][:members] = "New name"
    params[:approved_names] = ["New name"]
    requires_user(:update_species_list, ["observer", "list_species_lists"], params, false, spl.user.login)
    assert_redirected_to(:controller => "observer", :action => "show_species_list")
    spl = SpeciesList.find(spl.id)
    assert_equal(sp_count + 1, spl.observations.size)
  end
  
  def test_update_species_list_multiple_match
    spl = @unknown_species_list
    sp_count = spl.observations.size
    name = @amanita_baccata_arora
    assert(!spl.name_included(name))
    params = spl_params(spl)
    params[:list][:members] = name.text_name
    requires_user(:update_species_list, ["observer", "list_species_lists"], params, false, spl.user.login)
    assert_redirected_to(:controller => "observer", :action => "edit_species_list")
    spl = SpeciesList.find(spl.id)
    assert_equal(sp_count, spl.observations.size)
    assert(!spl.name_included(name))
  end
  
  def test_update_species_list_chosen_multiple_match
    spl = @unknown_species_list
    sp_count = spl.observations.size
    name = @amanita_baccata_arora
    assert(!spl.name_included(name))
    params = spl_params(spl)
    params[:list][:members] = name.text_name
    params[:chosen_names] = {name.text_name => name.id}
    requires_user(:update_species_list, ["observer", "list_species_lists"], params, false, spl.user.login)
    assert_redirected_to(:controller => "observer", :action => "show_species_list")
    spl = SpeciesList.find(spl.id)
    assert_equal(sp_count + 1, spl.observations.size)
    assert(spl.name_included(name))
  end

  def test_update_species_list_deprecated
    spl = @unknown_species_list
    sp_count = spl.observations.size
    name = @lactarius_subalpinus
    params = spl_params(spl)
    assert(!spl.name_included(name))
    params[:list][:members] = name.text_name
    requires_user(:update_species_list, ["observer", "list_species_lists"], params, false, spl.user.login)
    assert_redirected_to(:controller => "observer", :action => "edit_species_list")
    spl = SpeciesList.find(spl.id)
    assert_equal(sp_count, spl.observations.size)
    assert(!spl.name_included(name))
  end
  
  def test_update_species_list_approved_deprecated
    spl = @unknown_species_list
    sp_count = spl.observations.size
    name = @lactarius_subalpinus
    params = spl_params(spl)
    assert(!spl.name_included(name))
    params[:list][:members] = name.text_name
    params[:approved_deprecated_names] = [name.text_name]
    requires_user(:update_species_list, ["observer", "list_species_lists"], params, false, spl.user.login)
    assert_redirected_to(:controller => "observer", :action => "show_species_list")
    spl = SpeciesList.find(spl.id)
    assert_equal(sp_count + 1, spl.observations.size)
    assert(spl.name_included(name))
  end
  
  def test_update_species_list_valid_rename
    spl = @unknown_species_list
    sp_count = spl.observations.size
    name = @lactarius_subalpinus
    valid_name = @lactarius_alpinus
    params = spl_params(spl)
    assert(!spl.name_included(name))
    assert(!spl.name_included(valid_name))
    params[:list][:members] = name.text_name
    params[:approved_deprecated_names] = name.text_name
    params[:chosen_valid_names] = { name.text_name => valid_name.id.to_s }
    requires_user(:update_species_list, ["observer", "list_species_lists"], params, false, spl.user.login)
    assert_redirected_to(:controller => "observer", :action => "show_species_list")
    spl = SpeciesList.find(spl.id)
    assert_equal(sp_count + 1, spl.observations.size)
    assert(!spl.name_included(name))
    assert(spl.name_included(valid_name))
  end
  
  def test_update_species_list_checklist_add
    spl = @unknown_species_list
    sp_count = spl.observations.size
    name = @lactarius_alpinus
    params = spl_params(spl)
    assert(!spl.name_included(name))
    params[:checklist_data][name.id.to_s] = "checked"
    requires_user(:update_species_list, ["observer", "list_species_lists"], params, false, spl.user.login)
    assert_redirected_to(:controller => "observer", :action => "show_species_list")
    spl = SpeciesList.find(spl.id)
    assert_equal(sp_count + 1, spl.observations.size)
    assert(spl.name_included(name))
  end

  def test_update_species_list_deprecated_checklist
    spl = @unknown_species_list
    sp_count = spl.observations.size
    name = @lactarius_subalpinus
    params = spl_params(spl)
    assert(!spl.name_included(name))
    params[:checklist_data][name.id.to_s] = "checked"
    requires_user(:update_species_list, ["observer", "list_species_lists"], params, false, spl.user.login)
    assert_redirected_to(:controller => "observer", :action => "edit_species_list")
    spl = SpeciesList.find(spl.id)
    assert_equal(sp_count, spl.observations.size)
    assert(!spl.name_included(name))
  end

  def test_update_species_list_approved_deprecated_checklist
    spl = @unknown_species_list
    sp_count = spl.observations.size
    name = @lactarius_subalpinus
    params = spl_params(spl)
    assert(!spl.name_included(name))
    params[:checklist_data][name.id.to_s] = "checked"
    params[:approved_deprecated_names] = [name.search_name]
    requires_user(:update_species_list, ["observer", "list_species_lists"], params, false, spl.user.login)
    assert_redirected_to(:controller => "observer", :action => "show_species_list")
    spl = SpeciesList.find(spl.id)
    assert_equal(sp_count + 1, spl.observations.size)
    assert(spl.name_included(name))
  end

  def test_update_species_list_approved_renamed_deprecated_checklist
    spl = @unknown_species_list
    sp_count = spl.observations.size
    name = @lactarius_subalpinus
    valid_name = @lactarius_alpinus
    params = spl_params(spl)
    assert(!spl.name_included(name))
    params[:checklist_data][name.id.to_s] = "checked"
    params[:approved_deprecated_names] = [name.search_name]
    params[:chosen_valid_names] = { name.search_name => valid_name.id.to_s }
    requires_user(:update_species_list, ["observer", "list_species_lists"], params, false, spl.user.login)
    assert_redirected_to(:controller => "observer", :action => "show_species_list")
    spl = SpeciesList.find(spl.id)
    assert_equal(sp_count + 1, spl.observations.size)
    assert(!spl.name_included(name))
    assert(spl.name_included(valid_name))
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

  def test_change_synonyms
    name = @chlorophyllum_rachodes
    params = { :id => name.id }
    requires_login(:change_synonyms, params)
  end

  # combine two Names that have no Synonym
  def test_transfer_synonyms_1_1
    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)
    selected_past_name_count = selected_name.past_names.length
    
    add_name = @lepiota_rhacodes
    assert(!add_name.deprecated)
    assert_nil(add_name.synonym)
    add_past_name_count = add_name.past_names.length
    
    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.text_name },
      :deprecate => { :all => "checked" }
    }
    requires_login(:transfer_synonyms, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")

    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    assert_equal(add_past_name_count+1, add_name.past_names.length) # past name should have been created
    assert(!add_name.past_names[-1].deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_past_name_count, selected_name.past_names.length)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(2, add_synonym.names.size)
  end

  # combine two Names that have no Synonym and no deprecation
  def test_transfer_synonyms_1_1_nd
    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)
    
    add_name = @lepiota_rhacodes
    assert(!add_name.deprecated)
    assert_nil(add_name.synonym)
    
    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.text_name },
      :deprecate => { :all => "0" }
    }
    requires_login(:transfer_synonyms, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")

    add_name = Name.find(add_name.id)
    assert(!add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(2, add_synonym.names.size)
  end

  # add new name string to Name with no Synonym but not approved
  def test_transfer_synonyms_1_0_na
    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)
    params = {
      :id => selected_name.id,
      :synonym => { :members => "Lepiota rachodes var. rachodes" },
      :deprecate => { :all => "checked" }
    }
    requires_login(:transfer_synonyms, params, false)
    assert_redirected_to(:controller => "observer", :action => "change_synonyms")

    selected_name = Name.find(selected_name.id)
    assert_nil(selected_name.synonym)
    assert(!selected_name.deprecated)
  end

  # add new name string to Name with no Synonym but approved
  def test_transfer_synonyms_1_0_a
    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)
    params = {
      :id => selected_name.id,
      :synonym => { :members => "Lepiota rachodes var. rachodes" },
      :approved_names => ["Lepiota rachodes var. rachodes"],
      :deprecate => { :all => "checked" }
    }
    requires_login(:transfer_synonyms, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")
    selected_name = Name.find(selected_name.id)
    synonym = selected_name.synonym
    assert_not_nil(synonym)
    assert_equal(2, synonym.names.length)
    for n in synonym.names
      if n == selected_name
        assert(!n.deprecated)
      else
        assert(n.deprecated)
      end
    end
  end

  # add new name string to Name with no Synonym but approved
  def test_transfer_synonyms_1_00_a
    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)
    params = {
      :id => selected_name.id,
      :synonym => { :members => "Lepiota rachodes var. rachodes\r\nLepiota rhacodes var. rhacodes" },
      :approved_names => ["Lepiota rachodes var. rachodes", "Lepiota rhacodes var. rhacodes"],
      :deprecate => { :all => "checked" }
    }
    requires_login(:transfer_synonyms, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    synonym = selected_name.synonym
    assert_not_nil(synonym)
    assert_equal(3, synonym.names.length)
    for n in synonym.names
      if n == selected_name
        assert(!n.deprecated)
      else
        assert(n.deprecated)
      end
    end
  end

  # add a Name with no Synonym to a Name that has a Synonym
  def test_transfer_synonyms_n_1
    add_name = @lepiota_rachodes
    assert(!add_name.deprecated)
    assert_nil(add_name.synonym)

    selected_name = @chlorophyllum_rachodes
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    start_size = selected_synonym.names.size

    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :deprecate => { :all => "checked" }
    }
    requires_login(:transfer_synonyms, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")
    
    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    
    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(start_size + 1, add_synonym.names.size)
  end

  # add a Name with no Synonym to a Name that has a Synonym wih the alternates checked
  def test_transfer_synonyms_n_1_c
    add_name = @lepiota_rachodes
    assert(!add_name.deprecated)
    assert_nil(add_name.synonym)

    selected_name = @chlorophyllum_rachodes
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    start_size = selected_synonym.names.size

    existing_synonyms = {}
    split_name = nil
    for n in selected_synonym.names
      if n != selected_name # Check all names not matching the selected one
        assert(!n.deprecated)
        split_name = n
        existing_synonyms[n.id.to_s] = "checked"
      end
    end
    assert_not_nil(split_name)
    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :existing_synonyms => existing_synonyms,
      :deprecate => { :all => "checked" }
    }
    requires_login(:transfer_synonyms, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")
    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    
    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(start_size + 1, add_synonym.names.size)
    
    split_name = Name.find(split_name.id)
    assert(!split_name.deprecated)
    split_synonym = split_name.synonym
    assert_equal(add_synonym, split_synonym)
  end

  # add a Name with no Synonym to a Name that has a Synonym wih the alternates not checked
  def test_transfer_synonyms_n_1_nc
    add_name = @lepiota_rachodes
    assert(!add_name.deprecated)
    assert_nil(add_name.synonym)

    selected_name = @chlorophyllum_rachodes
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    start_size = selected_synonym.names.size

    existing_synonyms = {}
    split_name = nil
    for n in selected_synonym.names
      if n != selected_name # Uncheck all names not matching the selected one
        assert(!n.deprecated)
        split_name = n
        existing_synonyms[n.id.to_s] = "0"
      end
    end
    assert_not_nil(split_name)
    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :existing_synonyms => existing_synonyms,
      :deprecate => { :all => "checked" }
    }
    requires_login(:transfer_synonyms, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")
    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    
    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(2, add_synonym.names.size)
    
    split_name = Name.find(split_name.id)
    assert(!split_name.deprecated)
    assert_nil(split_name.synonym)
  end

  # add a Name that has a Synonym to a Name with no Synonym with no approved synonyms
  def test_transfer_synonyms_1_n_ns
    add_name = @chlorophyllum_rachodes
    assert(!add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    start_size = add_synonym.names.size
    
    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)
    
    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :deprecate => { :all => "checked" }
    }
    requires_login(:transfer_synonyms, params, false)
    assert_redirected_to(:controller => "observer", :action => "change_synonyms")

    add_name = Name.find(add_name.id)
    assert(!add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_nil(selected_synonym)

    assert_equal(start_size, add_synonym.names.size)
  end

  # add a Name that has a Synonym to a Name with no Synonym with all approved synonyms
  def test_transfer_synonyms_1_n_s
    add_name = @chlorophyllum_rachodes
    assert(!add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    start_size = add_synonym.names.size
    
    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)
    
    synonym_ids = (add_synonym.names.map {|n| n.id}).join('/')
    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :approved_synonyms => synonym_ids,
      :deprecate => { :all => "checked" }
    }
    requires_login(:transfer_synonyms, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")

    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)

    assert_equal(start_size+1, add_synonym.names.size)
  end

  # add a Name that has a Synonym to a Name with no Synonym with all approved synonyms
  def test_transfer_synonyms_1_n_l
    add_name = @chlorophyllum_rachodes
    assert(!add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    start_size = add_synonym.names.size
    
    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)
    
    synonym_names = (add_synonym.names.map {|n| n.search_name}).join("\r\n")
    params = {
      :id => selected_name.id,
      :synonym => { :members => synonym_names },
      :deprecate => { :all => "checked" }
    }
    requires_login(:transfer_synonyms, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")

    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)

    assert_equal(start_size+1, add_synonym.names.size)
  end

  # combine two Names that each have Synonyms with no chosen names
  def test_transfer_synonyms_n_n_ns
    add_name = @chlorophyllum_rachodes
    assert(!add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    add_start_size = add_synonym.names.size
    
    selected_name = @macrolepiota_rachodes
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size
    assert_not_equal(add_synonym, selected_synonym)
    
    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :deprecate => { :all => "checked" }
    }
    requires_login(:transfer_synonyms, params, false)
    assert_redirected_to(:controller => "observer", :action => "change_synonyms")
    add_name = Name.find(add_name.id)
    assert(!add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    assert_equal(add_start_size, add_synonym.names.size)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_not_equal(add_synonym, selected_synonym)
    assert_equal(selected_start_size, selected_synonym.names.size)
  end

  # combine two Names that each have Synonyms with all chosen names
  def test_transfer_synonyms_n_n_s
    add_name = @chlorophyllum_rachodes
    assert(!add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    add_start_size = add_synonym.names.size
    
    selected_name = @macrolepiota_rachodes
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size
    assert_not_equal(add_synonym, selected_synonym)
    
    synonym_ids = (add_synonym.names.map {|n| n.id}).join('/')
    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :approved_synonyms => synonym_ids,
      :deprecate => { :all => "checked" }
    }
    requires_login(:transfer_synonyms, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")
    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    assert_equal(add_start_size + selected_start_size, add_synonym.names.size)
    
    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
  end

  # combine two Names that each have Synonyms with all names listed
  def test_transfer_synonyms_n_n_l
    add_name = @chlorophyllum_rachodes
    assert(!add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    add_start_size = add_synonym.names.size
    
    selected_name = @macrolepiota_rachodes
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size
    assert_not_equal(add_synonym, selected_synonym)
    
    synonym_names = (add_synonym.names.map {|n| n.search_name}).join("\r\n")
    params = {
      :id => selected_name.id,
      :synonym => { :members => synonym_names },
      :deprecate => { :all => "checked" }
    }
    requires_login(:transfer_synonyms, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")
    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    assert_equal(add_start_size + selected_start_size, add_synonym.names.size)
    
    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
  end

  # split off a single name from a name with multiple synonyms
  def test_transfer_synonyms_split_3_1
    selected_name = @lactarius_alpinus
    assert(!selected_name.deprecated)
    selected_id = selected_name.id
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size
    
    existing_synonyms = {}
    split_name = nil
    for n in selected_synonym.names
      if n.id != selected_id
        assert(n.deprecated)
        if split_name.nil? # Find the first different name and uncheck it
          split_name = n
          existing_synonyms[n.id.to_s] = "0"
        else
          kept_name = n
          existing_synonyms[n.id.to_s] = "checked" # Check the rest
        end
      end
    end
    params = {
      :id => selected_name.id,
      :synonym => { :members => "" },
      :existing_synonyms => existing_synonyms,
      :deprecate => { :all => "checked" }
    }
    requires_login(:transfer_synonyms, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")
    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(selected_start_size - 1, selected_synonym.names.size)
    
    split_name = Name.find(split_name.id)
    assert(split_name.deprecated)
    assert_nil(split_name.synonym)
    
    assert(kept_name.deprecated)
  end

  # split 4 synonymized names into two sets of synonyms with two members each
  def test_transfer_synonyms_split_2_2
    selected_name = @lactarius_alpinus
    assert(!selected_name.deprecated)
    selected_id = selected_name.id
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size
    
    existing_synonyms = {}
    split_names = []
    count = 0
    for n in selected_synonym.names
      if n != selected_name
        assert(n.deprecated)
        if count < 2 # Uncheck two names
          split_names.push(n)
          existing_synonyms[n.id.to_s] = "0"
        else
          existing_synonyms[n.id.to_s] = "checked"
        end
        count += 1
      end
    end
    assert_equal(2, split_names.length)
    assert_not_equal(split_names[0], split_names[1])
    params = {
      :id => selected_name.id,
      :synonym => { :members => "" },
      :existing_synonyms => existing_synonyms,
      :deprecate => { :all => "checked" }
    }
    requires_login(:transfer_synonyms, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")
    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(selected_start_size - 2, selected_synonym.names.size)
    
    split_names[0] = Name.find(split_names[0].id)
    assert(split_names[0].deprecated)
    split_synonym = split_names[0].synonym
    assert_not_nil(split_synonym)
    split_names[1] = Name.find(split_names[1].id)
    assert(split_names[1].deprecated)
    assert_not_equal(split_names[0], split_names[1])
    assert_equal(split_synonym, split_names[1].synonym)
    assert_equal(2, split_synonym.names.size)
  end

  # take four synonymized names and separate off the non-deprecated one
  def test_transfer_synonyms_split_1_3
    selected_name = @lactarius_alpinus
    assert(!selected_name.deprecated)
    selected_id = selected_name.id
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size
    
    existing_synonyms = {}
    split_name = nil
    for n in selected_synonym.names
      if n != selected_name # Uncheck all names not matching the selected one
        assert(n.deprecated)
        split_name = n
        existing_synonyms[n.id.to_s] = "0"
      end
    end
    assert_not_nil(split_name)
    params = {
      :id => selected_name.id,
      :synonym => { :members => "" },
      :existing_synonyms => existing_synonyms,
      :deprecate => { :all => "checked" }
    }
    requires_login(:transfer_synonyms, params, false)
    assert_redirected_to(:controller => "observer", :action => "show_name")
    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)

    split_name = Name.find(split_name.id)
    assert(split_name.deprecated)
    split_synonym = split_name.synonym
    assert_not_nil(split_synonym)
    assert_equal(selected_start_size - 1, split_synonym.names.size)
  end
end
