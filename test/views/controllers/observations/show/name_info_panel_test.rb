# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::NameInfoPanelTest <
  ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:detailed_unknown_obs)
  end

  def test_renders_panel_id
    html = render(panel_with(@obs))

    assert_html(html, "#observation_name_info")
  end

  private

  def panel_with(obs)
    Views::Controllers::Observations::Show::NameInfoPanel.new(
      obs: obs, user: @user
    )
  end
end
