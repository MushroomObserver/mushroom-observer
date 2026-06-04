# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::ImagesPanelTest <
  ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:detailed_unknown_obs)
  end

  def test_no_images_renders_empty_panel_body
    obs = observations(:minimal_unknown_obs)
    html = render(panel_with(obs, []))

    assert_html(html, ".show_images")
    assert_no_html(html, ".list-group-item")
  end

  private

  def panel_with(obs, images)
    Views::Controllers::Observations::Show::ImagesPanel.new(
      obs: obs, images: images, user: @user
    )
  end
end
