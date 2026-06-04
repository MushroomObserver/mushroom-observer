# frozen_string_literal: true

require("test_helper")

class Components::ProjectButtonTest < ComponentTestCase
  def test_renders_a_get_button_with_the_supplied_name_and_target
    html = render(
      Components::ProjectButton.new(name: "Map", target: "/some/path")
    )

    # Renders a CrudButton::Get → plain anchor link.
    assert_html(html, "a[href='/some/path']", text: "Map")
  end

  # The component is a styling abstraction — its job is to produce
  # the specific Bootstrap classes both consumers were duplicating
  # pre-component. Per testing.md ("Don't pin cosmetic CSS classes"
  # exception for styling-abstraction components), assert on the
  # class set this component is supposed to emit.
  def test_renders_btn_default_at_btn_lg_size_with_row_spacing
    html = render(
      Components::ProjectButton.new(name: "Map", target: "/some/path")
    )

    assert_html(html, "a.btn.btn-default.btn-lg.my-3.mr-3[href='/some/path']")
  end
end
