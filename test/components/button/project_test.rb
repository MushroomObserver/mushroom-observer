# frozen_string_literal: true

require("test_helper")

class Components::ProjectButtonTest < ComponentTestCase
  def test_renders_a_get_button_with_the_supplied_name_and_target
    html = render_button

    # Renders a Button::Get → plain anchor link.
    assert_html(html, "a[href='/some/path']", text: "Map")
  end

  # rubocop:disable-next MO/NoCosmeticClassAssertion
  def test_renders_at_lg_size
    html = render_button

    assert_html(html, "a.btn.btn-secondary.btn-lg.my-3.mr-3[href='/some/path']")
  end

  private

  def render_button
    render(Components::Button::Project.new(name: "Map", target: "/some/path"))
  end
end
