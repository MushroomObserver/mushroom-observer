# frozen_string_literal: true

require("test_helper")

class ImageFragmentEXIFLinkTest < ComponentTestCase
  def test_renders_modal_toggle_button
    image = images(:connected_coprinus_comatus_image)

    html = render(Components::ImageFragment::EXIFLink.new(
                    image_id: image.id
                  ))

    assert_html(html, "a[data-controller='modal-toggle']" \
                      "[href='#{routes.exif_image_path(id: image.id)}']",
                text: :image_show_exif.t.as_displayed)
  end

  def test_applies_custom_link_class
    image = images(:connected_coprinus_comatus_image)

    html = render(Components::ImageFragment::EXIFLink.new(
                    image_id: image.id, link_class: "my-custom"
                  ))

    assert_html(html, "a.my-custom")
  end
end
