require File.dirname(__FILE__) + '/../test_helper'
require 'name_controller'

# Re-raise errors caught by the controller.
class NameController; def rescue_action(e) raise e end; end

class NameControllerTest < Test::Unit::TestCase
  fixtures :names
  fixtures :locations
  
  def setup
    @controller = NameController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # test_map - name with Observations that have Locations
  def test_map
    get_with_dump :map, :id => @agaricus_campestris.id
    assert_response :success
    assert_template 'map'
  end

  # test_map_no_loc - name with Observations that don't have Locations
  def test_map_no_loc
    get_with_dump :map, :id => @coprinus_comatus.id
    assert_response :success
    assert_template 'map'
  end

  # test_map_no_obs - name with no Observations
  def test_map_no_obs
    get_with_dump :map, :id => @conocybe_filaris.id
    assert_response :success
    assert_template 'map'
  end

end
