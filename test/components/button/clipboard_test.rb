# frozen_string_literal: true

require("test_helper")

class Components::Button::ClipboardTest < ComponentTestCase
  def test_renders_clipboard_button
    html = render_button(text: "ACGTACGT", name: "Copy this Sequence")

    assert_html(html, "button[type='button']")
    assert_html(html, "button[data-controller='clipboard']")
    assert_html(html, "button[data-clipboard-text-value='ACGTACGT']")
    assert_html(html, "button[data-action='clipboard#copy']")
    assert_html(html, "button[data-title='Copy this Sequence']")
  end

  def test_extra_class_is_appended
    html = render_button(text: "ACGT", name: "Copy", class: "ml-2")

    assert_html(html, "button.ml-2")
  end

  private

  def render_button(text:, name:, **)
    render(Components::Button::Clipboard.new(text: text, name: name, **))
  end
end
