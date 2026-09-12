# frozen_string_literal: true

require("test_helper")

class ImageFragmentEXIFLinkTest < ComponentTestCase
  def setup
    super
    @image = images(:connected_coprinus_comatus_image)
  end

  def test_renders_modal_toggle_button
    html = render_link(image_id: @image.id)

    assert_html(html, "a[data-controller='modal-toggle']" \
                      "[href='#{routes.exif_image_path(id: @image.id)}']",
                text: :image_show_exif.t.as_displayed)
  end

  def test_applies_custom_link_class
    html = render_link(image_id: @image.id, link_class: "my-custom")

    assert_html(html, "a.my-custom")
  end

  private

  def render_link(**)
    render(Components::ImageFragment::EXIFLink.new(**))
  end
end
