# frozen_string_literal: true

require("test_helper")

class ModalCloseButtonTest < ComponentTestCase
  def test_default_renders_dismiss_only_cancel_button
    html = render(Components::Modal::CloseButton.new)

    assert_html(html, "button[data-dismiss='modal']", text: :CANCEL.l)
    assert_no_html(html, "a")
  end

  def test_target_kwarg_renders_navigational_get_button
    html = render(Components::Modal::CloseButton.new(target: "/foo/cancel"))

    # Still dismisses the modal via JS AND navigates to the real path.
    assert_html(html, "a[href='/foo/cancel'][data-dismiss='modal']",
                text: :CANCEL.l)
  end

  def test_name_kwarg_overrides_default_label
    html = render(Components::Modal::CloseButton.new(name: "Nevermind"))

    assert_html(html, "button[data-dismiss='modal']", text: "Nevermind")
  end

  def test_extra_data_attrs_merge_with_dismiss
    html = render(Components::Modal::CloseButton.new(
                    data: { action: "confirm-modal#cancel" }
                  ))

    assert_html(html, "button[data-dismiss='modal']" \
                       "[data-action='confirm-modal#cancel']")
  end
end
