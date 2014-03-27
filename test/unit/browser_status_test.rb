# encoding: utf-8
require 'test_helper'

class BrowserStatusTest < Test::Unit::TestCase
  include BrowserStatus

  FF1 = 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.8) Gecko/20050524 Fedora/1.0.4-4 Firefox/1.0.4'
  IE7 = 'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0; WOW64; SLCC1; .NET CLR 2.0.50727; .NET CLR 3.0.04506; Media Center PC 5.0)'
  BOT = 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)'

  # Test add_args_to_url() helper.
  def test_add_args_to_url
    assert_equal('/abcdef?foo=bar&this=that',
      add_args_to_url('/abcdef', :foo => 'bar', :this => 'that'))
    assert_equal('/abcdef?foo=bar&this=that',
      add_args_to_url('/abcdef?foo=wrong', :foo => 'bar', :this => 'that'))
    assert_equal('/abcdef?a=2&foo=%22bar%22&this=that',
      add_args_to_url('/abcdef?foo=wrong&a=2', :foo => '"bar"', :this => 'that'))
    assert_equal('/blah/blah/5?arg=new',
      add_args_to_url('/blah/blah/5', :arg => 'new'))
    assert_equal('/blah/blah/4?arg=new',
      add_args_to_url('/blah/blah/5', :arg => 'new', :id => 4))
    # Valid utf-8 address and arg.
    assert_equal("/voilà?arg=a%C4%8D%E2%82%AC%CE%B5nt",
      add_args_to_url('/voilà', :arg => 'ač€εnt'))
    # Invalid utf-8 address and arg.
    assert_equal("/blah\x80",
      add_args_to_url("/blah\x80", :x => "foo\xA0"))
  end

  # Test parse_user_agent() helper.
  def test_user_agent
    assert_equal([:ie, 7.0], parse_user_agent(IE7))
    assert_equal([:firefox, 1.0], parse_user_agent(FF1))
    assert_equal([:robot, 0.0],parse_user_agent(BOT))
  end
end
