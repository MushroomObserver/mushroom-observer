# frozen_string_literal: true

require("test_helper")

class ButtonNewTest < ComponentTestCase
  # rubocop:disable-next MO/NoCosmeticClassAssertion
  def test_variant_overrides_default_framing
    html = render_new(target: routes.new_herbarium_path, variant: :outline)

    assert_html(html, "a.btn.btn-outline-default")
  end

  def test_tab_shortcut_derives_target_and_name
    obs = observations(:minimal_unknown_obs)
    tab = ::Tab::Observation::AddToSpeciesList.new(observation: obs)
    html = render_new(tab: tab)

    assert_html(html, "a[href='#{tab.path}']", text: tab.title.as_displayed)
  end

  private

  def render_new(**)
    render(Components::Button::New.new(**))
  end
end
