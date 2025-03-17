# frozen_string_literal: true

require("test_helper")

# test the application-wide helpers
class ApplicationHelperTest < ActionView::TestCase
  def test_add_args_to_url_two_args
    assert_equal("/abcdef?foo=bar&this=that",
                 add_args_to_url("/abcdef", foo: "bar", this: "that"))
  end

  def test_add_args_to_url_arg_replaces_url_parameter
    assert_equal("/abcdef?foo=bar&this=that",
                 add_args_to_url("/abcdef?foo=wrong", foo: "bar", this: "that"))
  end

  def test_add_args_to_url_append_args_to_url
    assert_equal("/abcdef?a=2&foo=%22bar%22&this=that",
                 add_args_to_url("/abcdef?foo=wrong&a=2",
                                 foo: '"bar"', this: "that"))
  end

  def test_add_args_to_url_ending_with_id
    assert_equal("/blah/blah/5?arg=new",
                 add_args_to_url("/blah/blah/5", arg: "new"))
  end

  def test_add_args_to_url_id_arg_replaces_id_in_url
    assert_equal("/blah/blah/4?arg=new",
                 add_args_to_url("/blah/blah/5", arg: "new", id: 4))
  end

  def test_add_args_to_url_valid_utf_8_address_and_arg
    assert_equal("/voilà?arg=a%C4%8D%E2%82%AC%CE%B5nt",
                 add_args_to_url("/voilà", arg: "ač€εnt"))
  end

  def test_add_args_to_url_invalid_utf_8_address_and_arg
    assert_equal("/blah\x80",
                 add_args_to_url("/blah\x80", x: "foo\xA0"))
  end
end
