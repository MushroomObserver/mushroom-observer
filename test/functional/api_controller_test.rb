require File.dirname(__FILE__) + '/../test_helper'
require 'api_controller'

class ApiControllerTest < Test::Unit::TestCase
  fixtures :all

  def setup
    @controller = ApiController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_simple
    get(:observations, :id => 1)
    print "\n----------------------------------------\n"
    print @response.body
    print "\n----------------------------------------\n"
  end
end
