# frozen_string_literal: true

require "test_helper"

class FormCarouselItemTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @image = images(:connected_coprinus_comatus_image)
  end

  def test_renders_with_img_id_prop_in_html_id
    component = Components::FormCarouselItem.new(
      user: @user,
      image: @image,
      img_id: "123",
      index: 0,
      upload: false
    )
    html = render(component)

    # Should use the img_id in the carousel item's id attribute
    assert_includes(html, 'id="carousel_item_123"')
    # Should NOT have the missing id fallback
    assert_not_includes(html, "carousel_item_img_id_missing")
  end

  def test_renders_with_img_id_prop_as_integer_in_html_id
    component = Components::FormCarouselItem.new(
      user: @user,
      image: @image,
      img_id: 456,
      index: 0,
      upload: false
    )
    html = render(component)

    # Integer img_id should be converted to string and used in id
    assert_includes(html, 'id="carousel_item_456"')
    # Should NOT have the missing id fallback
    assert_not_includes(html, "carousel_item_img_id_missing")
  end

  def test_renders_with_upload_true_and_img_id
    component = Components::FormCarouselItem.new(
      user: @user,
      image: nil,
      img_id: "upload_789",
      index: 0,
      upload: true
    )
    html = render(component)

    # Should use the provided img_id even for uploads
    assert_includes(html, 'id="carousel_item_upload_789"')
    # Should NOT have the missing id fallback
    assert_not_includes(html, "carousel_item_img_id_missing")
  end

  def test_renders_with_upload_true_but_no_img_id_shows_fallback
    component = Components::FormCarouselItem.new(
      user: @user,
      image: nil,
      img_id: nil,
      index: 0,
      upload: true
    )
    html = render(component)

    # Without img_id, should fall back to img_id_missing
    assert_includes(html, 'id="carousel_item_img_id_missing"')
  end

  def test_extracts_img_id_from_image_when_no_explicit_img_id
    component = Components::FormCarouselItem.new(
      user: @user,
      image: @image,
      index: 0,
      upload: false
    )
    html = render(component)

    # Should use the image's id when no explicit img_id provided
    assert_includes(html, "id=\"carousel_item_#{@image.id}\"")
    # Should NOT have the missing id fallback
    assert_not_includes(html, "carousel_item_img_id_missing")
  end
end
