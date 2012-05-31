# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot')

class ApiControllerTest < FunctionalTestCase
  def test_basic_get_requests
    # for model in [Comment, Image, Location, Name, Observation, SpeciesList, User]
    for model in [Comment, Image, Location, Name, Observation, User]
      for detail in [:none, :low, :high]
        get(model.table_name.to_sym, :detail => detail)
        api = assigns(:api)
        assert_no_api_errors(api)
        assert_objs_equal(model.first, api.results.first)
      end
    end
  end

  def assert_no_api_errors(api=nil)
    api ||= assigns(:api)
    msg = "Caught API Errors:\n" + api.errors.map(&:to_s).join("\n")
    assert_block(msg) { api.errors.empty? }
  end

  # # Basic comment request.
  # def test_get_comments
  #
  #   get(:comments, :detail => :high)
  #   @doc = REXML::Document.new(@response.body)
  #
  #   assert_xml_exists('/response', @response.body)
  #
  #   assert_xml_attr(2,               '/response/results/number')
  #   assert_xml_text(/^\d+(\.\d+)+$/, '/response/version')
  #   assert_xml_text(/^\d+-\d+-\d+$/, '/response/run_date')
  #   assert_xml_text(/^\d+\.\d+$/,    '/response/run_time')
  #   assert_xml_text('SELECT DISTINCT comments.id FROM comments LIMIT 0, 100',
  #                                    '/response/query')
  #   assert_xml_text(2,               '/response/num_records')
  #   assert_xml_text(1,               '/response/num_pages')
  #   assert_xml_text(1,               '/response/page')
  #
  #   assert_xml_name('comment',                              '/response/results/1')
  #   assert_xml_attr(1,                                      '/response/results/1/id')
  #   assert_xml_attr("#{HTTP_DOMAIN}/comment/show_comment/1",'/response/results/1/url')
  #   assert_xml_text('2006-03-02 21:14:00',                  '/response/results/1/created')
  #   assert_xml_text('A comment on minimal unknown',         '/response/results/1/summary')
  #   assert_xml_text('<p>Wow! That&#8217;s really cool</p>', '/response/results/1/content')
  #   assert_xml_name('user',                                 '/response/results/1/user')
  #   assert_xml_attr(1,                                      '/response/results/1/user/id')
  #   assert_xml_attr("#{HTTP_DOMAIN}/observer/show_user/1",  '/response/results/1/user/url')
  #   assert_xml_text('rolf',                                 '/response/results/1/user/login')
  #   assert_xml_text('Rolf Singer',                          '/response/results/1/user/legal_name')
  #
  #   assert_xml_name('comment', '/response/results/2')
  #   assert_xml_attr(2,         '/response/results/2/id')
  #
  #   assert_xml_none('/response/errors')
  # end
  #
  # # This is how to stuff an image into the (test) request body.
  # # @request.env['RAW_POST_DATA'] = File.read('test_image.jpg')
end
