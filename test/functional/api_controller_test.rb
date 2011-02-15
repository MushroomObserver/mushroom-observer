# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot')

class ApiControllerTest < FunctionalTestCase

  # This is a good place to test this stuff, since the filters are simplified.
  def test_filters
    @request.env['HTTP_ACCEPT_LANGUAGE'] = "pt-pt,pt;q=0.5"
    get(:test)
    assert_nil(@controller.instance_variable_get('@user'))
    assert_nil(User.current)
    assert_equal(:'pt-BR', Locale.code)
    assert_equal({}, cookies)
    assert_equal({'locale'=>'pt-BR','flash'=>{}}, session.data)
    session.data.delete('locale')

    @request.env['HTTP_ACCEPT_LANGUAGE'] = "pt-pt,xx-xx;q=0.5"
    get(:test)
    assert_equal(:'pt-BR', Locale.code)
    session.data.delete('locale')

    @request.env['HTTP_ACCEPT_LANGUAGE'] = "pt-pt,en;q=0.5"
    get(:test)
    assert_equal(:'en-US', Locale.code)
    session.data.delete('locale')

    @request.env['HTTP_ACCEPT_LANGUAGE'] = "en-xx,en;q=0.5"
    get(:test)
    assert_equal(:'en-US', Locale.code)

    @request.env['HTTP_ACCEPT_LANGUAGE'] = "ru-*"
    get(:test)
    assert_equal(:'en-US', Locale.code)
  end

  def check_address(name, format, good)
    p = { :name => name, :format => format }
    get(:ajax_geocode, p)
    result = @response.body
    assert(result)
    num_strings = result.split("\n")
    if good
      assert_equal(4, num_strings.length)
      num_strings.each do |s|
        assert(s.to_f != 0.0)
      end
    else
      assert_equal(0, num_strings.length)
    end
  end

  def test_geocode_address
    check_address("North Falmouth, Massachusetts, USA", "postal", true)
    check_address("USA, Massachusetts, North Falmouth", "scientific", true)
    check_address("Foo, Bar, Baz", "postal", false)
    
    # This address is special since Google only likes in the following order
    address = "North bound Rest Area, State Highway 33, between Pomeroy and Athens, Ohio, USA"
    check_address(address, "postal", true)
    check_address(address, "scientific", false)
    check_address(Location.reverse_name(address), "postal", false)
    check_address(Location.reverse_name(address), "scientific", true)
  end
  
#   # Basic comment request.
#   def test_get_comments
# 
#     get(:comments, :detail => :high)
#     @doc = REXML::Document.new(@response.body)
# 
#     assert_xml_exists('/response', @response.body)
# 
#     assert_xml_attr(2,               '/response/results/number')
#     assert_xml_text(/^\d+(\.\d+)+$/, '/response/version')
#     assert_xml_text(/^\d+-\d+-\d+$/, '/response/run_date')
#     assert_xml_text(/^\d+\.\d+$/,    '/response/run_time')
#     assert_xml_text('SELECT DISTINCT comments.id FROM comments LIMIT 0, 100',
#                                      '/response/query')
#     assert_xml_text(2,               '/response/num_records')
#     assert_xml_text(1,               '/response/num_pages')
#     assert_xml_text(1,               '/response/page')
# 
#     assert_xml_name('comment',                              '/response/results/1')
#     assert_xml_attr(1,                                      '/response/results/1/id')
#     assert_xml_attr("#{HTTP_DOMAIN}/comment/show_comment/1",'/response/results/1/url')
#     assert_xml_text('2006-03-02 21:14:00',                  '/response/results/1/created')
#     assert_xml_text('A comment on minimal unknown',         '/response/results/1/summary')
#     assert_xml_text('<p>Wow! That&#8217;s really cool</p>', '/response/results/1/content')
#     assert_xml_name('user',                                 '/response/results/1/user')
#     assert_xml_attr(1,                                      '/response/results/1/user/id')
#     assert_xml_attr("#{HTTP_DOMAIN}/observer/show_user/1",  '/response/results/1/user/url')
#     assert_xml_text('rolf',                                 '/response/results/1/user/login')
#     assert_xml_text('Rolf Singer',                          '/response/results/1/user/legal_name')
# 
#     assert_xml_name('comment', '/response/results/2')
#     assert_xml_attr(2,         '/response/results/2/id')
# 
#     assert_xml_none('/response/errors')
#   end
# 
#   def test_get_images
#     get(:images, :detail => :high)
#   end
# 
#   def test_get_licenses
#     get(:licenses, :detail => :high)
#   end
# 
#   def test_get_locations
#     get(:locations, :detail => :high)
#   end
# 
#   def test_get_names
#     get(:names, :detail => :high)
#   end
# 
#   def test_get_namings
#     get(:namings, :detail => :high)
#   end
# 
#   def test_get_observations
#     get(:observations, :detail => :high)
#   end
# 
#   def test_get_users
#     get(:users, :detail => :high)
#   end
# 
#   def test_get_votes
#     get(:votes, :detail => :high)
#   end
# 
#   # This is how to stuff an image into the (test) request body.
#   # @request.env['RAW_POST_DATA'] = File.read('test_image.jpg')
end
