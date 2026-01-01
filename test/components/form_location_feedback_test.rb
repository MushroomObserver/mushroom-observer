# frozen_string_literal: true

require "test_helper"

class FormLocationFeedbackTest < ComponentTestCase
  def test_renders_nothing_when_no_reasons
    assert_empty(Nokogiri::HTML(render_feedback(nil)).text.strip)
    assert_empty(Nokogiri::HTML(render_feedback([])).text.strip)
  end

  def test_renders_warning_alert_with_reasons
    html = render_feedback(["Location not found".html_safe])

    assert_html(html, ".alert-warning#dubious_location_messages.my-3")
    assert_html(html, "body", text: "Location not found")
    assert_html(html, ".help-note")
  end

  def test_renders_multiple_reasons_with_br_tags
    reasons = ["First reason", "Second reason", "Third reason"].map(&:html_safe)
    html = render_feedback(reasons)

    reasons.each { |r| assert_html(html, "body", text: r) }
    assert_html(html, "br", count: 2)
  end

  def test_renders_html_entities_without_double_escaping
    html = render_feedback(["Unknown country &#8216;Test&#8217;".html_safe])

    assert_match(/&#8216;/, html)
    assert_no_match(/&amp;#8216;/, html)
  end

  def test_accepts_symbol_button_parameter
    html = render(Components::FormLocationFeedback.new(
                    dubious_where_reasons: ["Reason".html_safe],
                    button: :CREATE
                  ))

    assert_html(html, ".alert-warning#dubious_location_messages")
    assert_match(/#{:CREATE.l}/, html)
  end

  private

  def render_feedback(reasons)
    render(Components::FormLocationFeedback.new(
             dubious_where_reasons: reasons,
             button: "Save"
           ))
  end
end
