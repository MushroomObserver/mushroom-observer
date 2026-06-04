# frozen_string_literal: true

require("test_helper")
require_relative("parity_helper")

class Views::Controllers::Observations::Show::NameInfoPanelTest <
  ComponentTestCase
  include Views::Controllers::Observations::Show::ParityHelper

  def test_renders_panel_id
    html = render(panel_with(@obs))

    assert_html(html, "#observation_name_info")
  end

  def test_parity_logged_in_user
    obs = observations(:detailed_unknown_obs)

    erb_html = render_legacy_erb(
      "name_info", obs: obs, consensus: nil, user: @user
    )
    phlex_html = render(panel_with(obs))

    assert_html_element_equivalent(
      erb_html, phlex_html, selector: "#observation_name_info",
                            label: "name_info logged-in user"
    )
  end

  private

  def panel_with(obs)
    Views::Controllers::Observations::Show::NameInfoPanel.new(
      obs: obs, user: @user
    )
  end
end
