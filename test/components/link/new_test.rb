# frozen_string_literal: true

require("test_helper")

class LinkNewTest < ComponentTestCase
  def test_target_path_renders_default_add_name_and_icon
    html = render_new(target: routes.new_herbarium_path)

    assert_html(html, "a[href='#{routes.new_herbarium_path}']",
                text: :add.ti.as_displayed)
    assert_html(html, "a svg.mo-icon-add")
  end

  def test_explicit_name_overrides_default
    html = render_new(target: routes.new_herbarium_path, name: "Go")

    assert_html(html, "a", text: "Go")
  end

  def test_tab_shortcut_uses_tab_title_not_default_add
    obs = observations(:minimal_unknown_obs)
    tab = ::Tab::Observation::AddToSpeciesList.new(observation: obs)
    html = render_new(tab: tab)

    assert_html(html, "a[href='#{tab.path}']", text: tab.title.as_displayed)
    assert_html(html, "a svg.mo-icon-add")
  end

  private

  def render_new(**)
    render(Components::Link::New.new(**))
  end
end
