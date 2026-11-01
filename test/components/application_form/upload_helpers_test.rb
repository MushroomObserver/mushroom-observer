# frozen_string_literal: true

require "test_helper"

# Tests for the `upload_fields`/`image_namespace`
# ApplicationForm helpers (app/components/application_form/
# upload_helpers.rb).
class UploadHelpersTest < ComponentTestCase
  include ApplicationFormFieldTestHelpers

  # Upload fields tests
  def test_upload_fields_renders_all_components
    # Create an observation for testing upload fields
    observation = observations(:minimal_unknown_obs)

    form = render_upload_form(observation) do
      upload_fields(
        copyright_holder: "Test User",
        copyright_year: 2024,
        licenses: [["Creative Commons", 1], ["Public Domain", 2]],
        upload_license_id: 1
      )
    end

    # Image file field
    assert_html(form, "input[type='file']")
    assert_includes(form, :image.ti)

    # Copyright holder field
    assert_includes(form, :image_copyright_holder.l)
    assert_html(form, "input[value='Test User']")

    # Year select
    assert_includes(form, :when.ti)
    assert_html(form, "select")
    assert_html(form, "option[value='2024'][selected]")

    # License select
    assert_includes(form, :license.ti)
    assert_includes(form, "Creative Commons")
    assert_includes(form, "Public Domain")
  end

  def test_upload_fields_with_custom_label
    observation = observations(:minimal_unknown_obs)

    form = render_upload_form(observation) do
      upload_fields(
        file_field_label: "Custom Label:",
        copyright_holder: "User",
        copyright_year: 2024,
        licenses: [["CC", 1]],
        upload_license_id: 1
      )
    end

    assert_includes(form, "Custom Label:")
  end

  # Image namespace tests
  def test_image_namespace_creates_nested_fields
    observation = observations(:minimal_unknown_obs)

    form = render_upload_form(observation) do
      image_namespace(:good_image, 123) do |ns|
        render(ns.field(:notes).text(wrapper_options: { label: "Notes" }))
      end
    end

    # Should create nested param structure: observation[good_image][123][notes]
    assert_html(form, "input[name='observation[good_image][123][notes]']")
    assert_html(form, "input[id='observation_good_image_123_notes']")
  end

  def test_image_namespace_with_image_type
    observation = observations(:minimal_unknown_obs)

    form = render_upload_form(observation) do
      image_namespace(:image, 456) do |ns|
        render(ns.field(:when).text(wrapper_options: { label: "When" }))
      end
    end

    assert_html(form, "input[name='observation[image][456][when]']")
  end
end
