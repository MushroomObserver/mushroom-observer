# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::ObservationDetailsPanelTest <
  ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:detailed_unknown_obs)
  end

  def test_renders_panel_id
    html = render(panel_with(@obs))

    assert_html(html, "#observation_details")
  end

  private

  def panel_with(obs, user = @user)
    Views::Controllers::Observations::Show::ObservationDetailsPanel.new(
      obs: obs, user: user, sites: [], siblings: []
    )
  end
end
