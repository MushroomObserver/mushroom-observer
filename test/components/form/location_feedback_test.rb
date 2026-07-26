# frozen_string_literal: true

require "test_helper"

class FormLocationFeedbackTest < ComponentTestCase
  def test_renders_nothing_when_no_reasons
    assert_empty(render_feedback(nil))
    assert_empty(render_feedback([]))
  end

  def test_renders_warning_alert_with_reasons
    html = render_feedback([[:location_dubious_empty, {}]])

    # `#dubious_location_messages` is the durable identifier; the
    # `.alert-warning` / `.my-3` Bootstrap classes are pure paint.
    assert_html(html, "#dubious_location_messages")
    assert_html(html, "#dubious_location_messages",
                text: :location_dubious_empty.t.as_displayed)
    assert_html(html, ".help-note")
    # Help text should include the button name
    help_note = Nokogiri::HTML(html).at_css(".help-note")
    assert(help_note.text.include?("Save"), "Help text should include button")
  end

  def test_renders_multiple_reasons_with_br_tags
    reasons = [
      [:location_dubious_empty, {}],
      [:location_dubious_commas, {}],
      [:location_dubious_bad_char, { char: "@" }]
    ]
    html = render_feedback(reasons)

    reasons.each do |tag, args|
      assert_html(html, "#dubious_location_messages",
                  text: tag.t(**args).as_displayed)
    end
    assert_html(html, "br", count: 2)
  end

  def test_renders_html_entities_without_double_escaping
    # Textile turns the straight quotes in location_dubious_unknown_country
    # ("Unknown country '[country]'") into smart-quote entities.
    html = render_feedback(
      [[:location_dubious_unknown_country, { country: "Test" }]]
    )

    assert_includes(html, "&#8216;")
    assert_not_includes(html, "&amp;#8216;")
  end

  def test_accepts_symbol_button_parameter
    html = render(Components::Form::LocationFeedback.new(
                    dubious_where_reasons: [[:location_dubious_empty, {}]],
                    button: :create
                  ))

    assert_html(html, ".alert-warning#dubious_location_messages",
                text: :create.ti)
  end

  private

  def render_feedback(reasons)
    render(Components::Form::LocationFeedback.new(
             dubious_where_reasons: reasons,
             button: "Save"
           ))
  end
end
