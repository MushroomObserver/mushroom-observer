# frozen_string_literal: true

require "test_helper"

class FormLocationFeedbackTest < ComponentTestCase
  def test_renders_nothing_when_no_reasons
    assert_empty(render_feedback(nil))
    assert_empty(render_feedback([]))
  end

  def test_renders_warning_alert_with_reasons
    html = render_feedback(["Location not found".html_safe])

    # `#dubious_location_messages` is the durable identifier; the
    # `.alert-warning` / `.my-3` Bootstrap classes are pure paint.
    assert_html(html, "#dubious_location_messages")
    assert_html(html, "body", text: "Location not found")
    assert_html(html, ".help-note")
    # Help note should include the button name
    help_note = Nokogiri::HTML(html).at_css(".help-note")
    assert(help_note.text.include?("Save"), "Help note should include button")
  end

  def test_renders_multiple_reasons_with_br_tags
    reasons = ["First reason", "Second reason", "Third reason"].map(&:html_safe)
    html = render_feedback(reasons)

    reasons.each { |r| assert_html(html, "body", text: r) }
    assert_html(html, "br", count: 2)
  end

  def test_renders_html_entities_without_double_escaping
    html = render_feedback(["Unknown country &#8216;Test&#8217;".html_safe])

    assert_includes(html, "&#8216;")
    assert_not_includes(html, "&amp;#8216;")
  end

  def test_accepts_symbol_button_parameter
    html = render(Components::Form::LocationFeedback.new(
                    dubious_where_reasons: ["Reason".html_safe],
                    button: :CREATE
                  ))

    assert_html(html, ".alert-warning#dubious_location_messages",
                text: :CREATE.l)
  end

  private

  def render_feedback(reasons)
    render(Components::Form::LocationFeedback.new(
             dubious_where_reasons: reasons,
             button: "Save"
           ))
  end
end
