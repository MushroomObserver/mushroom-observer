require 'rubygems'
require 'activerecord'
require 'action_view/helpers/tag_helper'
require 'action_view/helpers/javascript_helper'
require 'action_controller/mime_type'
require 'test/unit'
require 'browser_status'

class TestRequest
  attr_accessor :method
  attr_accessor :request_uri
  attr_accessor :env

  def initialize(args={})
    self.method      = args[:method]
    self.request_uri = args[:request_uri]
    self.env         = args[:env]
  end
end

class BrowserStatusTest < Test::Unit::TestCase
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::JavascriptHelper
  include BrowserStatus

  NS5 = 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.8) Gecko/20050524 Fedora/1.0.4-4 Firefox/1.0.4'
  IE7 = 'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0; WOW64; SLCC1; .NET CLR 2.0.50727; .NET CLR 3.0.04506; Media Center PC 5.0)'
  BOT = 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)'

  attr_accessor :request
  attr_accessor :params
  attr_accessor :session
  attr_accessor :cookies

  # Test add_args_to_url() helper.
  def test_add_args_to_url
    assert_equal('/abcdef?foo=bar&this=that',
      add_args_to_url('/abcdef', :foo => 'bar', :this => 'that'))
    assert_equal('/abcdef?foo=bar&this=that',
      add_args_to_url('/abcdef?foo=wrong', :foo => 'bar', :this => 'that'))
    assert_equal('/abcdef?a=2&foo=%22bar%22&this=that',
      add_args_to_url('/abcdef?foo=wrong&a=2', :foo => '"bar"', :this => 'that'))
  end

  # Test user_agent() helper.
  def test_user_agent
    assert_equal(:ie, _user_agent(IE7))
    assert_equal(:ns, _user_agent(NS5))
    assert_equal(:robot, _user_agent(BOT))
  end

  # Test various cases for report_browser_status.
  def test_report_browser_status
    self.request = TestRequest.new(
      :method      => :get,
      :request_uri => '/foo/bar?var=val'
    )
    self.session = {}

    @session_working = false
    @js = false
    str = report_browser_status
    assert_equal(nil, str)

    @session_working = true
    @js = false
    str = report_browser_status
    assert(str.match(/<script/))

    @js = true
    str = report_browser_status
    assert(str.match(/<noscript/))

    session[:js_override] = :off
    str = report_browser_status
    assert_equal(nil, str)
  end

  # Test various cases for browser_status filter.
  def test_browser_status
    self.request = TestRequest.new(
      :env => { 'HTTP_USER_AGENT' => NS5 }
    )
    self.params  = {}
    self.session = {}
    self.cookies = {}

    # Start fresh -- nothing should be working yet.
    browser_status
    assert(session[:_working])
    assert_equal('1', cookies[:_enabled])
    assert(!@session_working)
    assert(!@cookies_enabled)
    assert(!@js)
    assert(@ua[:ns])
    assert(@ua[:ns5])
    assert_equal(5.0, @ua_version)

    # If working, it would now redirect with "_js=on".
    # (Change ua, too, for kicks.)
    self.request.env['HTTP_USER_AGENT'] = IE7
    self.params[:_js] = 'on'

    browser_status
    assert(@session_working)
    assert(@cookies_enabled)
    assert(@js)
    assert(@ua[:ie])
    assert(@ua[:ie7])
    assert_equal(7.0, @ua_version)
  end
end
