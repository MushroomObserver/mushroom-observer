# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot')

class AjaxControllerTest < FunctionalTestCase

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

    @request.env['HTTP_ACCEPT_LANGUAGE'] = "zh-*"
    get(:test)
    assert_equal(:'en-US', Locale.code)
  end

  def check_address(name, format, good)
    p = { :name => name, :format => format }
    get(:geocode, p)
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

  def test_get_pivotal_story
    if PIVOTAL_USERNAME != 'username'
      get(:pivotal, :type => 'story', :id => PIVOTAL_TEST_ID)
      assert_match(/This is a test story/, @response.body)
      assert_match(/Posted by.*Rolf Singer/, @response.body)
      assert_match(/this is a test comment/, @response.body)
      assert_match(/By:.*Mary Newbie/, @response.body)
      assert_match(/Post Comment/, @response.body)
    end
  end
end
