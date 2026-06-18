# frozen_string_literal: true

require("test_helper")

class HelpNoteTest < ComponentTestCase
  def test_default_renders_span_with_help_note_classes
    html = render(Components::Help::Note.new(:span, "(optional)"))

    # Default `<span>` shape — used inline as a parenthetical
    # hint next to a label. `mr-3` gives breathing room to the
    # right of the inline marker.
    assert_html(html, "span.help-note.mr-3", text: "(optional)")
  end

  def test_element_override_picks_tag
    html = render(Components::Help::Note.new(:p, "Some note"))

    assert_html(html, "p.help-note", text: "Some note")
  end

  def test_block_form_renders_block_content
    html = render(Components::Help::Note.new(:div)) { "From block" }

    # Block-form lets callers compose content with markup the
    # `string:` slot can't carry — e.g. nested components.
    assert_html(html, "div.help-note", text: "From block")
  end

  def test_extra_class_appends_to_help_note_classes
    html = render(Components::Help::Note.new(
                    :span, "x", class: "extra-thing"
                  ))

    assert_html(html, "span.help-note.mr-3.extra-thing")
  end

  def test_extra_attributes_pass_through
    html = render(Components::Help::Note.new(
                    :span, "x", id: "h", data: { foo: "bar" }
                  ))

    assert_html(html, "span#h.help-note")
    assert_html(html, "span[data-foo='bar']")
  end

  def test_renders_no_content_when_neither_string_nor_block
    html = render(Components::Help::Note.new(:span))

    # Defensive — when no content is supplied the wrapper still
    # renders (matches the legacy helper, which `content_tag`'d
    # an empty body). Callers can always opt out by not rendering
    # the component at all.
    assert_html(html, "span.help-note")
  end
end
