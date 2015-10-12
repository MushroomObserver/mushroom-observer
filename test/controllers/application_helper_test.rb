# encoding: utf-8
require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  def test_add_args_to_url
    assert_equal("/abcdef?foo=bar&this=that",
                 add_args_to_url("/abcdef", foo: "bar", this: "that"))
    assert_equal("/abcdef?foo=bar&this=that",
                 add_args_to_url('/abcdef?foo=wrong', foo: "bar", this: "that"))
    assert_equal("/abcdef?a=2&foo=%22bar%22&this=that",
                 add_args_to_url("/abcdef?foo=wrong&a=2", foo: '"bar"',
                                 this: "that"))
    assert_equal("/blah/blah/5?arg=new",
                 add_args_to_url("/blah/blah/5", arg: "new"))
    assert_equal("/blah/blah/4?arg=new",
                 add_args_to_url("/blah/blah/5", arg: "new", id: 4))
    # Valid utf-8 address and arg.
    assert_equal("/voilà?arg=a%C4%8D%E2%82%AC%CE%B5nt",
                 add_args_to_url("/voilà", arg: "ač€εnt"))
    # Invalid utf-8 address and arg.
    assert_equal("/blah\x80",
                 add_args_to_url("/blah\x80", x: "foo\xA0"))
  end

  def test_textile_markup_should_be_escaped
  	textile = "**Bold**"
  	escaped = "&lt;div class=&quot;textile&quot;&gt;&lt;p&gt;&lt;b&gt;Bold&lt;/b&gt;&lt;/p&gt;&lt;/div&gt;"
		assert_equal escaped, escape_html(textile.tpl)
  end

  def test_conditional_content_tags
    assert_nil(content_tag_if(nil, :p, "Hello world!"))

    # use examples from Rails documentation
    assert_equal("<p>Hello world!</p>",
                 content_tag_if(true, :p, "Hello world!"))
    assert_equal('<div class="strong"><p>Hello world!</p></div>',
                 content_tag_if(true, :div,
                                content_tag(:p, "Hello world!"),
                                            class: "strong"))
    assert_equal('<div class="strong highlight">Hello world!</div>',
                 content_tag_if(true, :div, "Hello world!",
                                class: ["strong", "highlight"]))

    options =  "...options..."
    assert_equal('<select multiple="multiple">...options...</select>',
                 content_tag_if(true, "select", options, multiple: true))

    assert_equal('<div class="strong">Hello world!</div>',
                 content_tag_if(true, :div, class: "strong") do
                    "Hello world!"
                 end)

    assert_nil(content_tag_unless(true, :p, "Hello world!"))
    assert_equal("<p>Hello world!</p>",
                 content_tag_unless(false, :p, "Hello world!"))

  end
end
