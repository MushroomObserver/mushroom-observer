# frozen_string_literal: true

require "test_helper"

class FormImageFieldsTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @image = images(:connected_coprinus_comatus_image)
  end

  def test_existing_image_renders_all_fields
    html = render_fields(image: @image, img_id: @image.id, upload: false)

    # All form fields present
    assert_html(html, "textarea[name*='notes']")
    assert_html(html, "select[name*='when']")
    assert_html(html, "input[name*='copyright_holder']")
    assert_html(html, "select[name*='license_id']")
    assert_html(html, "input[name*='original_name']")

    # Uses good_image namespace for existing images
    assert_includes(html, "observation[good_image]")

    # No upload messages
    assert_no_html(html, "div.carousel-upload-messages")
  end

  def test_upload_image_excludes_original_name
    html = render_fields(image: nil, img_id: 123, upload: true)

    # Form fields present
    assert_html(html, "textarea[name*='notes']")
    assert_html(html, "select[name*='when']")
    assert_html(html, "input[name*='copyright_holder']")
    assert_html(html, "select[name*='license_id']")

    # Original name NOT present for uploads
    assert_no_html(html, "input[name*='original_name']")

    # Uses image namespace for uploads (within observation namespace)
    assert_includes(html, "observation[image]")

    # Upload messages container present
    assert_html(html, "div.carousel-upload-messages")
    assert_html(html, "span.warn-text")
    assert_html(html, "span.info-text")
  end

  def test_existing_image_uses_image_values
    html = render_fields(image: @image, img_id: @image.id, upload: false)

    # Image values populated
    assert_includes(html, @image.copyright_holder) if @image.copyright_holder
    assert_includes(html, @image.original_name) if @image.original_name.present?
  end

  def test_license_options_use_user_license_for_upload
    html = render_fields(image: nil, img_id: 123, upload: true)

    # License select present with options
    assert_html(html, "select[name*='license_id']")
    assert_html(html, "select option")
  end

  def test_license_options_use_image_license_for_existing
    html = render_fields(image: @image, img_id: @image.id, upload: false)

    # License select present with options
    assert_html(html, "select[name*='license_id']")
    assert_html(html, "select option")
  end

  private

  def render_fields(image:, img_id:, upload:)
    render(Components::FormImageFields.new(
             user: @user,
             image: image,
             img_id: img_id,
             upload: upload
           ))
  end
end
