# frozen_string_literal: true

require("test_helper")

class ModalLinkTest < ComponentTestCase
  def test_plain_modal_link_renders_link_with_stimulus_data_attrs
    html = render(Components::ModalLink.new(
                    "comment", "Edit", "/edit"
                  ))

    # Without `:icon`, renders a plain anchor wired up to the
    # `modal-toggle` Stimulus controller.
    assert_html(html, "a[href='/edit']" \
                      "[data-modal='modal_comment']" \
                      "[data-controller='modal-toggle']" \
                      "[data-action='modal-toggle#showModal:prevent']",
                text: "Edit")
  end

  def test_icon_modal_link_renders_through_icon_link
    html = render(Components::ModalLink.new(
                    "comment", "Edit", "/edit", icon: :edit
                  ))

    # With `:icon`, delegates to Components::IconLink — the anchor
    # carries the modal data attrs AND the icon-link tooltip wiring.
    assert_html(html, "a.icon-link[href='/edit']" \
                      "[data-modal='modal_comment']" \
                      "[data-controller='modal-toggle']" \
                      "[data-action='modal-toggle#showModal:prevent']")
    assert_html(html, "a span.glyphicon-edit")
    # IconLink puts the label in an sr-only span when show_text is off.
    assert_html(html, "a span.sr-only", text: "Edit")
  end

  def test_caller_data_attrs_deep_merge_with_stimulus_attrs
    html = render(Components::ModalLink.new(
                    "comment", "Edit", "/edit",
                    data: { my_attr: "v" }
                  ))

    # Caller's `:data` deep-merges with the modal stimulus wiring;
    # both ends up on the anchor.
    assert_html(html, "a[data-controller='modal-toggle']" \
                      "[data-my-attr='v']")
  end

  def test_caller_class_passes_through
    html = render(Components::ModalLink.new(
                    "x", "Label", "/x", class: "extra-class"
                  ))

    assert_html(html, "a.extra-class[href='/x']")
  end
end
