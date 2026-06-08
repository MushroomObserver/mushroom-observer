# frozen_string_literal: true

require("test_helper")

# test the content helpers
class ContentHelperTest < ActionView::TestCase
  include ContentHelper

  def test_escape_textiled_string
    textile = "**Bold**"
    escaped = "&lt;div class=&quot;textile&quot;&gt;&lt;p&gt;&lt;b&gt;Bold" \
              "&lt;/b&gt;&lt;/p&gt;&lt;/div&gt;"
    assert_equal(escaped, escape_html(textile.tpl),
                 "Expected escape_html to HTML-escape the textilized string")
  end

  def test_indent
    assert_equal(tag.span("&nbsp;".html_safe, class: "ml-3"), indent,
                 "Expected indent to return an nbsp span with ml-3 class")
  end

  def test_textilize_without_paragraph
    str = "**bold**"
    expected = Textile.textilize_without_paragraph(str, do_object_links: false)
    assert_equal(
      expected, textilize_without_paragraph(str),
      "helper should delegate to Textile.textilize_without_paragraph"
    )
  end

  def test_textilize
    str = "**bold**"
    expected = Textile.textilize(str, do_object_links: false)
    assert_equal(expected, textilize(str),
                 "Expected helper to delegate to Textile.textilize")
  end

  def test_content_tag_if_false_condition_returns_nil
    assert_nil(content_tag_if(false, :span, "text"),
               "Expected nil when condition is false")
  end

  def test_content_tag_if_true_condition_renders_tag
    assert_equal("<span>text</span>",
                 content_tag_if(true, :span, "text"),
                 "Expected span tag when condition is true")
  end

  def test_content_tag_unless_false_condition_renders_tag
    assert_equal("<span>text</span>",
                 content_tag_unless(false, :span, "text"),
                 "Expected span tag when condition is false (unless)")
  end

  def test_content_tag_unless_true_condition_returns_nil
    assert_nil(content_tag_unless(true, :span, "text"),
               "Expected nil when condition is true (unless)")
  end
end
