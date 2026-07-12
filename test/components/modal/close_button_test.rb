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

  def test_target_kwarg_accepts_an_abstract_model
    # Matches Components::Button::Project's target: type -- not every
    # caller has a plain String path handy; some want to pass a model
    # and let CRUDPathBuilding derive the path.
    herbarium = herbaria(:nybg_herbarium)
    html = render(Components::Modal::CloseButton.new(target: herbarium))

    assert_html(html, "a[href='#{routes.herbarium_path(id: herbarium.id)}']" \
                       "[data-dismiss='modal']")
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

  def test_caller_data_cannot_override_dismiss
    # A caller-supplied data: { dismiss: ... } must never win -- that
    # would silently break the component's whole point (closing the
    # modal).
    html = render(Components::Modal::CloseButton.new(
                    data: { dismiss: "something-else" }
                  ))

    assert_html(html, "button[data-dismiss='modal']")
    assert_no_html(html, "button[data-dismiss='something-else']")
  end

  private

  def routes
    Rails.application.routes.url_helpers
  end
end
