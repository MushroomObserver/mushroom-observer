# frozen_string_literal: true

require("test_helper")

# test the content helpers
module ContentHelperTest
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
