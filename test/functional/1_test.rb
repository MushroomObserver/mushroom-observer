# A convenient place to put individual tests that are currently failing to
# speed up the edit/test cycle.
#
# Note that if you are using another controller you ned to update the various
# references.  Also for some reason if you switch to using the ImageController
# and then run the entire test suite you get errors.

require File.dirname(__FILE__) + '/../test_helper'
require 'observer_controller'
# require 'fileutils'
# require 'sequence_state'

# Re-raise errors caught by the controller.
class ObserverController; def rescue_action(e) raise e end; end

class CurrentTest < Test::Unit::TestCase
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
  fixtures :licenses
  fixtures :namings
  fixtures :votes
  fixtures :naming_reasons
  fixtures :locations
  fixtures :notifications

  def setup
    @controller = ObserverController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def teardown
    if File.exists?(IMG_DIR)
      FileUtils.rm_rf(IMG_DIR)
    end
  end

  def test_trivial
    assert_equal(1+1, 2)
  end

  # Test constructing observations in various ways (with minimal namings).
  def test_construct_observation_generic(params, observation_count, naming_count, name_count, page=nil)
    o_count = Observation.find(:all).length
    g_count = Naming.find(:all).length
    n_count = Name.find(:all).length
    params[:observation] = {}                   if !params[:observation]
    params[:observation][:where] = "right here" if !params[:observation][:where]
    params[:observation]["when(1i)"] = "2007"
    params[:observation]["when(2i)"] = "3"
    params[:observation]["when(3i)"] = "9"
    params[:observation][:specimen]  = "0"
    params[:vote] = {}          if !params[:vote]
    params[:vote][:value] = "3" if !params[:vote][:value]
    post_requires_login(:create_observation, params, false)
    if observation_count == 1
      assert_redirected_to(:controller => "observer", :action => (page || "show_observation"))
    else
      assert_response(:success)
    end
    assert((o_count + observation_count) == Observation.find(:all).length)
    assert((g_count + naming_count) == Naming.find(:all).length)
    assert((n_count + name_count) == Name.find(:all).length)
    assert_equal(10+observation_count+2*naming_count+10*name_count, @rolf.reload.contribution)
  end

  def test_construct_observation_with_notification
    count_before = QueuedEmail.find(:all).length
    name = @agaricus_campestris
    notifications = Notification.find_all_by_flavor_and_obj_id(:name, name.id)
    assert_equal(2, notifications.length)

    where = "test_construct_observation_with_notification"
    test_construct_observation_generic({
      :observation => { :where => where },
      :name => { :name => name.text_name }
    }, 1,1,0, "show_notifications")
    obs = assigns(:observation)
    nam = assigns(:naming)
    assert_equal(where, obs.where) # Make sure it's the right observation
    assert_equal(name, nam.name) # Make sure it's the right name
    assert_not_nil(obs.rss_log)
    
    count_after = QueuedEmail.find(:all).length
    assert_equal(count_before+2, count_after)
  end
end
