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

  def test_form_content_slot_replaces_body_and_footer
    # `with_form_content` lets the caller render a single component
    # (typically a form) that emits its own `.modal-body` and
    # `.modal-footer`, so a single `<form>` tag wraps both — keeping
    # the submit button (in `.modal-footer`) naturally inside the form.
    html = render(Components::Modal.new(
                    id: "modal_form", title: "Edit"
                  )) do |m|
      m.with_form_content do
        '<form action="/x" method="post">' \
          '<div class="modal-body"><input name="foo"></div>' \
          '<div class="modal-footer">' \
          '<button type="submit">Save</button>' \
          "</div>" \
          "</form>".html_safe
      end
    end

    # Modal chrome is still rendered (header + close button).
    assert_html(html, ".modal#modal_form .modal-content > .modal-header")
    # The form_content output replaces the default body+footer slot
    # rendering — there is exactly one `.modal-body` and one
    # `.modal-footer`, and both live inside the same `<form>`.
    assert_html(html, ".modal-content > form[action='/x']", count: 1)
    assert_html(html, ".modal-content > form > .modal-body > input[name='foo']")
    assert_html(html,
                ".modal-content > form > .modal-footer > button[type='submit']",
                text: "Save")
    # The submit button is inside the form (HTML5 form submission works
    # without needing `form='id'` attribute association on the button).
    assert_html(html, "form > .modal-footer button[type='submit']")
  end

  def test_form_content_slot_supersedes_body_and_footer_slots
    # When both `with_form_content` and the body/footer slots are set,
    # `with_form_content` wins. (Callers shouldn't mix them; this just
    # documents the precedence so a stray `with_body` call doesn't
    # silently double-render.)
    html = render(Components::Modal.new(
                    id: "modal_either", title: "T"
                  )) do |m|
      m.with_body { "<p>should-not-appear</p>".html_safe }
      m.with_footer { "<button>also-not</button>".html_safe }
      m.with_form_content { "<form><p>wins</p></form>".html_safe }
    end

    assert_html(html, ".modal-content > form > p", text: "wins")
    assert_no_html(html, ".modal-body")
    assert_no_html(html, ".modal-footer")
  end
end
