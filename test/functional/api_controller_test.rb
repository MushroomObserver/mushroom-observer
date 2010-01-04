require File.dirname(__FILE__) + '/../test_helper'
require 'api_controller'

class ApiControllerTest < Test::Unit::TestCase
  fixtures :all

  def setup
    @controller = ApiController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # ----------------------------
  #  XML helpers.
  # ----------------------------

  # Dump out XML tree.
  def dump_xml(e, indent)
    print "#{indent}#{e.name}"
    if e.has_attributes?
      attrs = []
      e.attributes.each do |a,v|
        attrs << "#{a}=#{v}"
      end
      print "(#{attrs.join(' ')})"
    end
    if e.has_text? && e.text =~ /\S/
      txt = e.text.gsub(/^\s+|\s+$/, '').gsub(/\s+/, ' ')
      txt = "\"#{txt}\"" if txt.match(' ')
      print " = #{txt}"
    end
    print "\n"
    if e.has_elements?
      e.elements.each do |child|
        dump_xml(child, indent + '  ')
      end
    end
  end

  # Retrieve the element identified by key, e.g.,
  #   get_xml_element('/root/child/grand-child')
  # If any of the children are numbers, it gets the Nth child at that level.
  def get_xml_element(key)
    key.sub(/^\//,'').split('/').inject(@doc) do |elem, key|
      elem = elem.elements[key.match(/^\d+$/) ? key.to_i : key]
    end
  end

  # Assert that a given element is of the given type, e.g.,
  #   assert_xml_name('comment', '/response/results/1')
  def assert_xml_name(val, key)
    _assert_xml(val, get_xml_element(key).name)
  end

  # Assert that a given element has a given attribute, e.g.,
  #   assert_xml_name(1234, '/response/results/1/id')
  def assert_xml_attr(val, key)
    key.match(/^(.*)\/(.*)/)
    key, attr = $1, $2
    _assert_xml(val, get_xml_element(key).attributes[attr])
  end

  # Assert that a given element has a given value, e.g.,
  #   assert_xml_name('rolf', '/response/results/1/login')
  def assert_xml_text(val, key)
    _assert_xml(val, get_xml_element(key).text)
  end

  # Private helper method used in XML assertions above:
  #   _assert_xml(10, @doc.elements['/response/results'].attributes['number'])
  #   _assert_xml('rolf', @doc.elements['/response/user/login'].text)
  #   _assert_xml(/\d\d-\d\d-\d\d/, @doc.elements['/response/script_date'].text)
  def _assert_xml(val, str)
    if val.is_a?(Regexp)
      assert(str.to_s.gsub(/^\s+|\s+$/,'').gsub(/\s+/,' ').match(val))
    else
      assert_equal(val.to_s.gsub(/^\s+|\s+$/,'').gsub(/\s+/,' '),
                   str.to_s.gsub(/^\s+|\s+$/,'').gsub(/\s+/,' '))
    end
  end

################################################################################

  # Basic comment request.
  def test_get_comments
    get(:comments)
    @doc = REXML::Document.new(@response.body)

    assert_xml_attr(2,               '/response/results/number')
    assert_xml_text(/^\d+(\.\d+)+$/, '/response/script_version')
    assert_xml_text(/^\d+-\d+-\d+$/, '/response/script_date')
    assert_xml_text(/^\d+-\d+-\d+$/, '/response/script_run_date')
    assert_xml_text(/^\d+\.\d+$/,    '/response/script_run_time')
    assert_xml_text('SELECT DISTINCT comments.id FROM comments LIMIT 0, 100',
                                     '/response/query')
    assert_xml_text(2,               '/response/num_records')
    assert_xml_text(1,               '/response/num_pages')
    assert_xml_text(1,               '/response/page')

    assert_xml_name('comment',                              '/response/results/1')
    assert_xml_attr(1,                                      '/response/results/1/id')
    assert_xml_attr("#{DOMAIN}/comment/show_comment/1",     '/response/results/1/url')
    assert_xml_text('2006-03-02 21:14:00',                  '/response/results/1/created')
    assert_xml_text('A comment on minimal unknown',         '/response/results/1/summary')
    assert_xml_text('<p>Wow! That&#8217;s really cool</p>', '/response/results/1/content')
    assert_xml_name('user',                                 '/response/results/1/user')
    assert_xml_attr(1,                                      '/response/results/1/user/id')
    assert_xml_attr("#{DOMAIN}/observer/show_user/1",       '/response/results/1/user/url')
    assert_xml_text('rolf',                                 '/response/results/1/user/login')
    assert_xml_text('Rolf Singer',                          '/response/results/1/user/legal_name')

    assert_xml_name('comment', '/response/results/2')
    assert_xml_attr(2,         '/response/results/2/id')
  end

  def test_get_images
    get(:images)
  end

  def test_get_licenses
    get(:licenses)
  end

  def test_get_locations
    get(:locations)
  end

  def test_get_names
    get(:names)
  end

  def test_get_namings
    get(:namings)
  end

  def test_get_observations
    get(:observations)
  end

  def test_get_users
    get(:users)
  end

  # This is how to stuff an image into the (test) request body.
  # @request.env['RAW_POST_DATA'] = File.read('test_image.jpg')
end
