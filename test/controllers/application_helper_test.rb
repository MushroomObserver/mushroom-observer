# frozen_string_literal: true

require("test_helper")

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

  def test_escape_textiled_string
    textile = "**Bold**"
    escaped = "&lt;div class=&quot;textile&quot;&gt;&lt;p&gt;&lt;b&gt;Bold" \
              "&lt;/b&gt;&lt;/p&gt;&lt;/div&gt;"
    assert_equal(escaped, escape_html(textile.tpl))
  end

  # test convience conditional content tags
  def test_content_tag_if_condition_false
    assert_nil(content_tag_if(nil, :p, "Hello world!"))
  end

  # tests using examples from or modeled on Rails documentation
  def test_content_tag_if_without_options
    assert_equal("<p>Hello world!</p>",
                 content_tag_if(true, :p, "Hello world!"))
  end

  def test_content_tag_if_with_content_block_arg
    assert_equal('<div class="strong"><p>Hello world!</p></div>',
                 content_tag_if(true, :div,
                                content_tag(:p, "Hello world!"),
                                class: "strong"))
  end

  def test_content_tag_if_with_content_block_with_options
    assert_equal('<div class="strong highlight">Hello world!</div>',
                 content_tag_if(true, :div, "Hello world!",
                                class: %w[strong highlight]))
  end

  def test_content_tag_if_with_attribute_with_no_value
    options = "...options..."
    assert_equal('<select multiple="multiple">...options...</select>',
                 content_tag_if(true, "select", options, multiple: true))
  end

  def test_content_tag_if_with_content_as_trailing_block
    assert_equal('<div class="strong">Hello world!</div>',
                 content_tag_if(true, :div, class: "strong") do
                   "Hello world!"
                 end)
  end

  def test_content_tag_unless_condition_true
    assert_nil(content_tag_unless(true, :p, "Hello world!"))
  end

  def test_content_tag_unless_condition_false
    assert_equal("<p>Hello world!</p>",
                 content_tag_unless(false, :p, "Hello world!"))
  end
end
