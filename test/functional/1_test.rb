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
  
  def test_ask_observation_question
    id = @coprinus_comatus_obs.id
    requires_login :ask_observation_question, {:id => id}
    assert_form_action :action => 'send_observation_question', :id => id
  end
end
