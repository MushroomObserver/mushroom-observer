# encoding: utf-8
require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase

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
end
