require File.dirname(__FILE__) + '/../test_helper'
require 'observer_controller'
require 'fileutils'

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

  def setup
    @controller = ObserverController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def teardown
  end

  def test_trivial
    assert_equal(1+1, 2)
  end
end
