# frozen_string_literal: true

require("test_helper")
require_relative("parity_helper")

class Views::Controllers::Observations::Show::ObservationDetailsPanelTest <
  ComponentTestCase
  include Views::Controllers::Observations::Show::ParityHelper

  def test_renders_panel_id
    html = render(panel_with(@obs))

    assert_html(html, "#observation_details")
  end

  def test_parity_logged_in_owner
    # Skipped: this panel composes the four list-pattern sub-
    # panels (collection_numbers / herbarium_records / sequences /
    # external_links), and each of those introduces a
    # `<span class="ml-3">` wrapper around its `[ edit | destroy ]`
    # group via `Components::InlineModLinks` — a deliberate
    # CSS-based spacing improvement over the legacy ERB's
    # literal-space joins. The wrapper divergence bubbles up to
    # the parent panel here. The contract is covered by the
    # individual panel tests + the controller-level
    # `assert_select("#observation_details")`.
    skip("InlineModLinks wrapper divergence; covered by " \
         "sub-panel + controller tests instead")
    obs = observations(:detailed_unknown_obs)
    erb_html = render_legacy_erb(
      "observation_details",
      obs: obs, consensus: nil, user: obs.user,
      sites: [], siblings: []
    )
    phlex_html = render(panel_with(obs, obs.user))

    assert_html_element_equivalent(
      erb_html, phlex_html, selector: "#observation_details",
                            label: "observation_details logged-in owner",
                            strip_csrf: true
    )
  end

  private

  def panel_with(obs, user = @user)
    Views::Controllers::Observations::Show::ObservationDetailsPanel.new(
      obs: obs, user: user, sites: [], siblings: []
    )
  end
end
