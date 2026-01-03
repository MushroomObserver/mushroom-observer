# frozen_string_literal: true

require "test_helper"

class FormCarouselItemTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @image = images(:connected_coprinus_comatus_image)
  end

  def test_renders_with_img_id_prop_in_html_id
    html = render_item(img_id: "123")

    assert_includes(html, 'id="carousel_item_123"')
    assert_not_includes(html, "carousel_item_img_id_missing")
  end

  def test_renders_with_img_id_prop_as_integer_in_html_id
    html = render_item(img_id: 456)

    assert_includes(html, 'id="carousel_item_456"')
    assert_not_includes(html, "carousel_item_img_id_missing")
  end

  def test_renders_with_upload_true_and_img_id
    html = render_item(image: nil, img_id: "upload_789", upload: true)

    assert_includes(html, 'id="carousel_item_upload_789"')
    assert_not_includes(html, "carousel_item_img_id_missing")
  end

  def test_renders_with_upload_true_but_no_img_id_shows_fallback
    html = render_item(image: nil, img_id: nil, upload: true)

    assert_includes(html, 'id="carousel_item_img_id_missing"')
  end

  def test_extracts_img_id_from_image_when_no_explicit_img_id
    html = render_item(img_id: nil)

    assert_includes(html, "id=\"carousel_item_#{@image.id}\"")
    assert_not_includes(html, "carousel_item_img_id_missing")
  end

  private

  def render_item(image: @image, img_id: nil, index: 0, upload: false)
    render(Components::FormCarouselItem.new(
             user: @user,
             image: image,
             img_id: img_id,
             index: index,
             upload: upload
           ))
  end
end
