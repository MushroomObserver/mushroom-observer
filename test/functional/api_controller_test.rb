require File.dirname(__FILE__) + '/../test_helper'
require 'api_controller'

class ApiControllerTest < Test::Unit::TestCase
  fixtures :users

  def setup
    @controller = ApiController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

################################################################################

  # Basic comment request.
  def test_get_comments
    local_fixtures :comments

    get(:comments, :detail => :high)
    @doc = REXML::Document.new(@response.body)

    assert_xml_exists('/response', @response.body)

    assert_xml_attr(2,               '/response/results/number')
    assert_xml_text(/^\d+(\.\d+)+$/, '/response/version')
    assert_xml_text(/^\d+-\d+-\d+$/, '/response/run_date')
    assert_xml_text(/^\d+\.\d+$/,    '/response/run_time')
    assert_xml_text('SELECT DISTINCT comments.id FROM comments LIMIT 0, 100',
                                     '/response/query')
    assert_xml_text(2,               '/response/num_records')
    assert_xml_text(1,               '/response/num_pages')
    assert_xml_text(1,               '/response/page')

    assert_xml_name('comment',                              '/response/results/1')
    assert_xml_attr(1,                                      '/response/results/1/id')
    assert_xml_attr("#{HTTP_DOMAIN}/comment/show_comment/1",'/response/results/1/url')
    assert_xml_text('2006-03-02 21:14:00',                  '/response/results/1/created')
    assert_xml_text('A comment on minimal unknown',         '/response/results/1/summary')
    assert_xml_text('<p>Wow! That&#8217;s really cool</p>', '/response/results/1/content')
    assert_xml_name('user',                                 '/response/results/1/user')
    assert_xml_attr(1,                                      '/response/results/1/user/id')
    assert_xml_attr("#{HTTP_DOMAIN}/observer/show_user/1",  '/response/results/1/user/url')
    assert_xml_text('rolf',                                 '/response/results/1/user/login')
    assert_xml_text('Rolf Singer',                          '/response/results/1/user/legal_name')

    assert_xml_name('comment', '/response/results/2')
    assert_xml_attr(2,         '/response/results/2/id')

    assert_xml_none('/response/errors')
  end

  def test_get_images
    local_fixtures :images
    get(:images, :detail => :high)
  end

  def test_get_licenses
    local_fixtures :licenses
    get(:licenses, :detail => :high)
  end

  def test_get_locations
    local_fixtures :locations
    get(:locations, :detail => :high)
  end

  def test_get_names
    local_fixtures :names
    get(:names, :detail => :high)
  end

  def test_get_namings
    local_fixtures :namings
    get(:namings, :detail => :high)
  end

  def test_get_observations
    local_fixtures :observations
    get(:observations, :detail => :high)
  end

  def test_get_users
    get(:users, :detail => :high)
  end

  def test_get_votes
    local_fixtures :votes
    get(:votes, :detail => :high)
  end

  # This is how to stuff an image into the (test) request body.
  # @request.env['RAW_POST_DATA'] = File.read('test_image.jpg')
end
