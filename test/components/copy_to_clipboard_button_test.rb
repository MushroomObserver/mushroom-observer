# frozen_string_literal: true

require("test_helper")

class CopyToClipboardButtonTest < ComponentTestCase
  def test_renders_copy_button
    html = render_button(text: "ACGTACGT", title: "Copy this Sequence")

    assert_html(html, "button[type='button']")
    assert_html(html, "button[data-controller='clipboard']")
    assert_html(html, "button[data-clipboard-text-value='ACGTACGT']")
    assert_html(html, "button[data-action='clipboard#copy']")
    assert_html(html, "button[data-title='Copy this Sequence']")
  end

  def test_extra_class_is_appended
    html = render_button(text: "ACGT", title: "Copy", extra_class: "ml-2")

    assert_html(html, "button.ml-2")
  end

  private

  def render_button(text:, title:, extra_class: nil)
    render(Components::CopyToClipboardButton.new(
             text: text, title: title, extra_class: extra_class
           ))
  end
end
