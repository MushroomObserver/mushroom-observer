# frozen_string_literal: true

require("test_helper")

class ModalLinkTest < ComponentTestCase
  def test_plain_modal_link_renders_link_with_stimulus_data_attrs
    html = render_modal

    assert_html(html, "a[href='/edit']" \
                      "[data-modal='modal_comment']" \
                      "[data-controller='modal-toggle']" \
                      "[data-action='modal-toggle#showModal:prevent']",
                text: "Edit")
  end

  def test_no_button_styling_by_default
    html = render_modal

    # Plain link — no btn classes unless button: is passed.
    assert_no_html(html, "a.btn")
  end

  def test_button_kwarg_adds_btn_classes
    html = render_modal(button: :outline)

    assert_html(html, "a.btn.btn-outline-default[href='/edit']")
  end

  def test_icon_modal_link_renders_through_icon_link
    html = render_modal(icon: :edit)

    # With icon, delegates to Link::Icon — anchor carries modal data attrs
    # AND the icon-link tooltip wiring.
    assert_html(html, "a.icon-link[href='/edit']" \
                      "[data-modal='modal_comment']" \
                      "[data-controller='modal-toggle']" \
                      "[data-action='modal-toggle#showModal:prevent']")
    assert_html(html, "a span.glyphicon-edit")
    assert_html(html, "a span.sr-only", text: "Edit")
  end

  def test_caller_data_attrs_deep_merge_with_stimulus_attrs
    html = render_modal(data: { my_attr: "v" })

    assert_html(html, "a[data-controller='modal-toggle']" \
                      "[data-my-attr='v']")
  end

  def test_caller_class_passes_through
    html = render_modal(class: "extra-class")

    assert_html(html, "a.extra-class[href='/edit']")
  end

  private

  def render_modal(**)
    render(Components::Link::Modal.new(
             modal_id: "comment", name: "Edit", target: "/edit", **
           ))
  end
end
