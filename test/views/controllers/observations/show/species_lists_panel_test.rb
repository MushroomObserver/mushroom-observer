# frozen_string_literal: true

require("test_helper")
require_relative("parity_helper")

class Views::Controllers::Observations::Show::SpeciesListsPanelTest <
  ComponentTestCase
  include Views::Controllers::Observations::Show::ParityHelper

  def test_no_species_lists_renders_panel_chrome_only
    obs = observations(:minimal_unknown_obs)
    skip("Need obs without species_lists") if obs.species_lists.any?

    html = render(panel_with(obs))

    assert_html(html, "#observation_species_lists")
    assert_no_html(html, "ul")
  end

  def test_parity_with_lists
    # Pick an obs that has at least one species_list.
    obs = ::Observation.joins(:species_lists).distinct.first ||
          skip("Need an obs attached to a species_list")

    erb_html = render_legacy_erb(
      "species_lists", obs: obs, user: @user, consensus: nil
    )
    phlex_html = render(panel_with(obs))

    assert_html_element_equivalent(
      erb_html, phlex_html, selector: "#observation_species_lists",
                            label: "species_lists with-lists"
    )
  end

  private

  def panel_with(obs)
    Views::Controllers::Observations::Show::SpeciesListsPanel.new(
      obs: obs, user: @user
    )
  end
end
