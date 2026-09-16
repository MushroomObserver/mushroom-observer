# frozen_string_literal: true

require("test_helper")

class ButtonEditTest < ComponentTestCase
  def test_target_renders_btn_default_framing
    herbarium = herbaria(:nybg_herbarium)
    html = render_edit(target: herbarium)

    path = routes.edit_herbarium_path(herbarium.id)
    assert_html(html, "a.btn.btn-default[href='#{path}']")
  end

  def test_variant_overrides_default_framing
    herbarium = herbaria(:nybg_herbarium)
    html = render_edit(target: herbarium, variant: :outline)

    assert_html(html, "a.btn.btn-outline-default")
  end

  def test_tab_shortcut_derives_target_and_name
    name = names(:fungi)
    tab = ::Tab::Name::Edit.new(name: name)
    html = render_edit(tab: tab)

    assert_html(html, "a.btn[href='#{routes.edit_name_path(name.id)}']",
                text: :show_name_edit_name.l.as_displayed)
  end

  private

  def render_edit(**)
    render(Components::Button::Edit.new(**))
  end
end
