# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::NameInfoPanelTest <
  ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:detailed_unknown_obs)
  end

  def test_renders_collapsed_placeholder
    html = render(panel_with(@obs))

    assert_html(html, "#observation_name_info")
    # Collapsed by default -- no "in" class, no fetched content yet.
    assert_html(html, "#observation_name_info_body.collapse")
    assert_no_html(html, "#observation_name_info_body.in")
    assert_html(html, "turbo-frame##{frame_id}:empty")
  end

  def test_toggle_targets_the_lazy_fetch_route
    html = render(panel_with(@obs))

    assert_html(
      html,
      "a[href='#{routes.name_info_panel_for_observation_path(@obs.id)}']" \
      "[data-target='#observation_name_info_body']" \
      "[data-turbo-frame='#{frame_id}']"
    )
  end

  private

  def frame_id = "name_info_frame_#{@obs.id}"

  def panel_with(obs)
    Views::Controllers::Observations::Show::NameInfoPanel.new(
      obs: obs, user: @user
    )
  end
end
