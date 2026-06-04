# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::SpeciesListsPanelTest <
  ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:detailed_unknown_obs)
  end

  def test_no_species_lists_renders_panel_chrome_only
    obs = observations(:minimal_unknown_obs)
    skip("Need obs without species_lists") if obs.species_lists.any?

    html = render(panel_with(obs))

    assert_html(html, "#observation_species_lists")
    assert_no_html(html, "ul")
  end

  private

  def panel_with(obs)
    Views::Controllers::Observations::Show::SpeciesListsPanel.new(
      obs: obs, user: @user
    )
  end
end
