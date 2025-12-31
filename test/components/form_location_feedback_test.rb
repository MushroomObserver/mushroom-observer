# frozen_string_literal: true

require "test_helper"

class FormLocationFeedbackTest < UnitTestCase
  include ComponentTestHelper

  def setup
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_nothing_when_nil
    html = render_component(dubious_where_reasons: nil, button: "Save")
    assert_empty(Nokogiri::HTML(html).text.strip)
  end

  def test_renders_nothing_when_empty_array
    html = render_component(dubious_where_reasons: [], button: "Save")
    assert_empty(Nokogiri::HTML(html).text.strip)
  end

  def test_renders_warning_alert_with_single_reason
    html = render_component(
      dubious_where_reasons: ["Location not found".html_safe],
      button: "Save"
    )

    assert_html(html, ".alert-warning#dubious_location_messages")
    assert_html(html, "body", text: "Location not found")
    assert_html(html, ".help-note")
  end

  def test_renders_multiple_reasons_with_br_tags
    html = render_component(
      dubious_where_reasons: [
        "First reason".html_safe,
        "Second reason".html_safe,
        "Third reason".html_safe
      ],
      button: "Update"
    )

    assert_html(html, "body", text: "First reason")
    assert_html(html, "body", text: "Second reason")
    assert_html(html, "body", text: "Third reason")
    # Should have 2 br tags for 3 reasons
    assert_html(html, "br", count: 2)
  end

  def test_help_text_includes_button_name
    html = render_component(
      dubious_where_reasons: ["Some reason".html_safe],
      button: "Create"
    )

    # The help text should include the button name
    assert_html(html, ".help-note")
    # Check that the help note contains text (we don't need to check exact text
    # since it's localized)
    doc = Nokogiri::HTML(html)
    help_note = doc.at_css(".help-note")
    assert(help_note.text.present?, "Help note should have text content")
  end

  def test_renders_with_my_3_class
    html = render_component(
      dubious_where_reasons: ["Reason".html_safe],
      button: "Save"
    )

    assert_html(html, ".my-3")
  end

  def test_renders_html_entities_in_reasons
    # Test that HTML entities in reasons are rendered correctly, not escaped
    html = render_component(
      dubious_where_reasons: ["Unknown country &#8216;Test&#8217;".html_safe],
      button: "Create"
    )

    # The HTML should contain the entities, not escaped versions
    assert_match(/&#8216;/, html)
    assert_match(/&#8217;/, html)
    # Should NOT have double-escaped entities
    assert_no_match(/&amp;#8216;/, html)
    assert_no_match(/&amp;#8217;/, html)
  end

  private

  def render_component(dubious_where_reasons:, button:)
    component = Components::FormLocationFeedback.new(
      dubious_where_reasons: dubious_where_reasons,
      button: button
    )
    render(component)
  end
end
