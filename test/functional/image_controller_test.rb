require File.dirname(__FILE__) + '/../test_helper'
require 'image_controller'

class FilePlus < File
  attr_accessor :content_type
end

class ImageControllerTest < Test::Unit::TestCase
  fixtures :images
  fixtures :observations
  fixtures :images_observations
  fixtures :namings
  fixtures :names
  fixtures :locations
  fixtures :users
  fixtures :licenses

  def setup
    @controller = ImageController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    # FileUtils.cp_r(IMG_DIR.gsub(/test_images$/, 'setup_images'), IMG_DIR)
  end

  def teardown
    if File.exists?(IMG_DIR)
      FileUtils.rm_rf(IMG_DIR)
    end
  end

  def test_images_by_title
    get_with_dump :images_by_title
    assert_response :success
    assert_template 'images_by_title'
  end

  def test_list_images
    get_with_dump :list_images
    assert_response :success
    assert_template 'list_images'
  end

  def test_next_image
    get_with_dump :next_image
    assert_redirected_to(:controller => "image", :action => "show_image", :id => 5)
  end

  def test_next_image_ss
    state = SequenceState.new({}, {}, Image.connection, :images)
    state.next()
    state.next()
    next_id = state.current_id
    state.prev()
    seq_states = {}
    seq_states[state.key] = state.session_data()
    @request.session[:seq_states] = seq_states
    params = {
      :seq_key => state.key,
      :id => state.current_id
    }
    get_with_dump :next_image, params
    assert_redirected_to(:controller => "image", :action => "show_image", :id => next_id)
  end

  # Test next_image in the context of a search
  def test_next_image_search
    search_state = SearchState.new({}, {}, :images)
    search_state.setup('Title', @controller.field_search(["n.search_name", "i.notes", "i.copyright_holder"], "%Notes%"),
      "n.search_name, `when` desc", :nothing)
    search_states = {}
    search_states[search_state.key] = search_state.session_data()
    @request.session[:search_states] = search_states
    params = {
      :search_seq => search_state.key
    }
    state = SequenceState.new(@request.session, params, Image.connection, :images)

    state.prev() # Really go to the start of the list
    state.next() # Peek ahead
    next_id = state.current_id
    state.prev() # Go back
    seq_states = {}
    seq_states[state.key] = state.session_data()
    @request.session[:seq_states] = seq_states
    params = {
      :seq_key => state.key,
      :id => state.current_id
    }
    get_with_dump :next_image, params # Now try it for real
    assert_redirected_to(:controller => "image", :action => "show_image", :id => next_id)
  end

  def test_prev_image
    get_with_dump :prev_image
    assert_redirected_to(:controller => "image", :action => "show_image")
  end

  def test_prev_image_ss
    state = SequenceState.new({}, {}, Image.connection, :images)
    state.next()
    prev_id = state.current_id
    state.next()
    seq_states = {}
    seq_states[state.key] = state.session_data()
    @request.session[:seq_states] = seq_states
    params = {
      :seq_key => state.key,
      :id => state.current_id
    }
    get_with_dump :prev_image, params
    assert_redirected_to(:controller => "image", :action => "show_image", :id => prev_id)
  end

  def test_show_image
    get_with_dump :show_image, :id => 1
    assert_response :success
    assert_template 'show_image'
  end

  def test_show_original
    get_with_dump :show_original, :id => 1
    assert_response :success
    assert_template 'show_original'
  end

  def test_image_search
    @request.session[:pattern] = "Notes"
    get_with_dump :image_search
    assert_response :success
    assert_template 'list_images'
    assert_equal "Images matching 'Notes'", @controller.instance_variable_get('@title')
    get_with_dump :image_search, { :page => 2 }
    assert_response :success
    assert_template 'list_images'
    assert_equal "Images matching 'Notes'", @controller.instance_variable_get('@title')
  end

  def test_image_search_next
    @request.session[:pattern] = "Notes"
    get_with_dump :image_search
    assert_response :success
    assert_template 'list_images'
  end
  
  def test_image_search_by_number
    @request.session[:pattern] = "3"
    get_with_dump :image_search
    assert_redirected_to(:controller => "image", :action => "show_image")
  end

  def test_add_image
    requires_login :add_image, {:id => @coprinus_comatus_obs.id}
    assert_form_action :action => 'add_image'
    # Check that image cannot be added to an observation the user doesn't own
    flash[:params] = nil # (disable the spontaneous logout fix!!!)
    get_with_dump :add_image, {:id => @minimal_unknown.id}
    assert_redirected_to(:controller => "observer", :action => "show_observation")
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

  def test_license_updater
    requires_login :license_updater
    assert_form_action :action => 'license_updater'
  end

  def test_update_licenses
    example_image = @agaricus_campestris_image
    user_id = example_image.user_id
    target_license = example_image.license
    new_license = @ccwiki30
    assert_not_equal(target_license, new_license)
    target_count = Image.find_all_by_user_id_and_license_id(user_id, target_license.id).length
    assert(target_count > 0)
    new_count = Image.find_all_by_user_id_and_license_id(user_id, new_license.id).length
    params = {
      :updates => {
        target_license.id.to_s => {
          example_image.copyright_holder => new_license.id.to_s
        }
      }
    }
    post_requires_login(:license_updater, params, false)
    assert_response :success
    assert_template 'license_updater'
    assert_equal(10, @rolf.reload.contribution)
    target_count_after = Image.find_all_by_user_id_and_license_id(user_id, target_license.id).length
    assert(target_count_after < target_count)
    new_count_after = Image.find_all_by_user_id_and_license_id(user_id, new_license.id).length
    assert(new_count_after > new_count)
    assert_equal(target_count_after + new_count_after, target_count + new_count)
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
    params = {"id"=>obs.id.to_s, "selected"=>selected}
    post_requires_login(:remove_images, params, false, "mary")
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal(10, @mary.reload.contribution)
    obs2 = Observation.find(obs.id) # Need to reload observation to pick up changes
    assert(!obs2.images.member?(image))
  end

  def test_destroy_image
    image = @turned_over
    obs = image.observations[0]
    assert(obs.images.member?(image))
    params = {"id"=>image.id.to_s}
    assert("mary" == image.user.login)
    requires_user(:destroy_image, ["image", "show_image"], params, false, "mary")
    assert_redirected_to(:controller => "image", :action => "list_images")
    assert_equal(0, @mary.reload.contribution)
    obs = Observation.find(obs.id) # Need to reload observation to pick up changes
    assert(!obs.images.member?(image))
  end

  def test_edit_image
    image = @connected_coprinus_comatus_image
    params = { "id" => image.id.to_s }
    assert("rolf" == image.user.login)
    requires_user(:edit_image, ['image', 'show_image'], params)
    assert_form_action :action => 'edit_image'
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
    post_requires_login :edit_image, params, false
    assert_redirected_to(:controller => "image", :action => "show_image")
    assert_equal(10, @rolf.reload.contribution)
    obs = Observation.find(obs.id)
    pat = "^.*: Image, %s, updated by %s\n" % [image.unique_text_name, obs.user.login]
    assert_equal(0, obs.rss_log.notes =~ Regexp.new(pat.gsub(/\(/,'\(').gsub(/\)/,'\)')))
  end

  def test_remove_images
    obs = @coprinus_comatus_obs
    params = { :id => obs.id }
    assert("rolf" == obs.user.login)
    requires_user(:remove_images, ['observer', 'show_observation'], params)
    assert_form_action :action => 'remove_images'
  end

  def test_resize_images
    requires_login :resize_images, {}, false
    assert_equal("You must be an admin to access resize_images.", flash[:notice])
    assert_redirected_to(:controller => "image", :action => "list_images")
    # How should real image files be handled?
  end

  def test_reuse_image
    obs = @agaricus_campestris_obs
    params = { :id => obs.id }
    assert("rolf" == obs.user.login)
    requires_user(:reuse_image, ['observer', 'show_observation'], params)
    assert_form_action :action => 'reuse_image_by_id'
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
    get_with_dump(:reuse_image_by_id, params)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs = Observation.find(obs.id) # Reload Observation
    assert(obs.images.member?(image))
  end

  def test_upload_image
    FileUtils.cp_r(IMG_DIR.gsub(/test_images$/, 'setup_images'), IMG_DIR)
    obs = @coprinus_comatus_obs
    img_count = obs.images.size
    file = FilePlus.new("test/fixtures/images/Coprinus_comatus.jpg")
    file.content_type = 'image/jpeg'
    params = {
      :id => obs.id,
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
    post_requires_user(:add_image, ['observer', 'show_observation'], params, false)
    assert_redirected_to(:controller => 'observer', :action => 'show_observation')
    assert_equal(20, @rolf.reload.contribution)
    obs = Observation.find(obs.id)
    assert(obs.images.size == (img_count + 1))
  end
end
