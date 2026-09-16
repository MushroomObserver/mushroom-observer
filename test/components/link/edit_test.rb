# frozen_string_literal: true

require("test_helper")

class LinkEditTest < ComponentTestCase
  def test_target_model_renders_default_name_and_edit_icon
    herbarium = herbaria(:nybg_herbarium)
    html = render_edit(target: herbarium)

    assert_html(html, "a[href='#{routes.edit_herbarium_path(herbarium.id)}']",
                text: :edit_object.t(type: herbarium.type_tag).as_displayed)
    assert_html(html, "a svg.mo-icon-edit")
  end

  def test_explicit_name_overrides_default
    herbarium = herbaria(:nybg_herbarium)
    html = render_edit(target: herbarium, name: "Go")

    assert_html(html, "a", text: "Go")
  end

  def test_tab_shortcut_uses_tab_title_not_default_name
    name = names(:fungi)
    tab = ::Tab::Name::Edit.new(name: name)
    html = render_edit(tab: tab)

    assert_html(html, "a[href='#{routes.edit_name_path(name.id)}']",
                text: :show_name_edit_name.l.as_displayed)
    assert_html(html, "a svg.mo-icon-edit")
  end

  private

  def render_edit(**)
    render(Components::Link::Edit.new(**))
  end
end
