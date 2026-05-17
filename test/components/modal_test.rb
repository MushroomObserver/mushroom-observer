# frozen_string_literal: true

require("test_helper")

class ModalTest < ComponentTestCase
  def test_renders_chrome_with_body_and_footer_slots
    html = render(Components::Modal.new(
                    id: "modal_thing", title: "Pick a thing"
                  )) do |m|
      m.with_body { "<p>body content</p>".html_safe }
      m.with_footer { "<button>OK</button>".html_safe }
    end

    # Modal nesting
    assert_html(html, ".modal#modal_thing[role='dialog']")
    assert_html(html, ".modal-dialog[role='document']")
    assert_html(html, ".modal-content")

    # Default chrome
    assert_html(html, ".modal-header > h4.modal-title#modal_thing_title",
                text: "Pick a thing")
    assert_html(html, ".modal-header > button.close[data-dismiss='modal']")

    # Body + footer rendered from slot content
    assert_html(html, ".modal-body#modal_thing_body > p",
                text: "body content")
    assert_html(html, ".modal-footer > button", text: "OK")

    # Default modal Stimulus controller
    assert_html(html, ".modal[data-controller='modal']")

    # Default styling: fade in (not auto-open)
    assert_includes(html, "class=\"modal fade\"")
    assert_not_includes(html, "modal-backdrop")
  end

  def test_renders_html_safe_title_unescaped
    # Regression: titles from MO's `.t` (textilize) are HTML-safe and
    # include rendered `<b>`/`<i>` tags. Modal must respect html_safe?
    # and not escape them. Bug surfaced in the comment-add modal where
    # taxon names showed literal `<b><i>Xylaria</i></b>` instead of
    # italicized bold text.
    title = "Add Comment to <b><i>Xylaria polymorpha</i></b>".html_safe
    html = render(Components::Modal.new(id: "modal_html", title: title))

    assert_html(html, ".modal-title > b > i", text: "Xylaria polymorpha")
    assert_not_includes(html, "&lt;b&gt;")
  end

  def test_auto_open_adds_backdrop_and_display_block
    html = render(Components::Modal.new(
                    id: "modal_auto", title: "Auto", auto_open: true
                  ))

    assert_html(html, ".modal-backdrop.fade.in")
    assert_includes(html, "class=\"modal fade in\"")
    assert_includes(html, "style=\"display: block;\"")
  end

  def test_extras_class_data_and_id_overrides
    html = render(Components::Modal.new(
                    id: "modal_x", title: "T",
                    extra_class: "modal-form",
                    extra_data: { identifier: "x", foo: "bar" },
                    title_id: "modal_x_header",
                    body_id: "modal_x_body"
                  )) do |m|
      m.with_body { "b".html_safe }
    end

    assert_includes(html, "class=\"modal fade modal-form\"")
    assert_html(html, ".modal[data-identifier='x'][data-foo='bar']")
    assert_html(html, "h4.modal-title#modal_x_header")
    assert_html(html, ".modal-body#modal_x_body")
    assert_html(html, ".modal[aria-labelledby='modal_x_header']")
  end

  def test_title_content_slot_overrides_title_prop
    html = render(Components::Modal.new(
                    id: "modal_slot", title: "ignored"
                  )) do |m|
      m.with_title_content { "<strong>custom</strong>".html_safe }
    end

    assert_html(html, ".modal-title > strong", text: "custom")
    assert_not_includes(html, "ignored")
  end
end
