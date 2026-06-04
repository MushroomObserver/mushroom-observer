# frozen_string_literal: true

require("test_helper")
require_relative("parity_helper")

class Views::Controllers::Observations::Show::ImagesPanelTest <
  ComponentTestCase
  include Views::Controllers::Observations::Show::ParityHelper

  def test_no_images_renders_empty_panel_body
    obs = observations(:minimal_unknown_obs)
    html = render(panel_with(obs, []))

    assert_html(html, ".show_images")
    assert_no_html(html, ".list-group-item")
  end

  def test_parity_with_images
    obs = @obs
    images = obs.images_sorted.to_a
    skip("Need obs with images") if images.empty?

    # The legacy `_images.erb` reads `@images` from the controller,
    # not a local; emulate via instance_variable_set.
    @controller.instance_variable_set(:@images, images)
    @controller.instance_variable_set(:@user, @user)
    erb_html = render_legacy_erb("images", obs: obs)
    phlex_html = render(panel_with(obs, images))

    assert_html_element_equivalent(
      erb_html, phlex_html, selector: ".show_images",
                            label: "images with-images"
    )
  end

  private

  def panel_with(obs, images)
    Views::Controllers::Observations::Show::ImagesPanel.new(
      obs: obs, images: images, user: @user
    )
  end
end
