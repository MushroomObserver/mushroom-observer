# frozen_string_literal: true

require "test_helper"

# Tests for the `file_field` ApplicationForm helper.
class FileFieldTest < ComponentTestCase
  include ApplicationFormFieldTestHelpers

  def setup
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)
  end

  # File field tests
  def test_file_field_renders_with_defaults
    form = render_form do
      file_field(:image, label: "Upload Image")
    end

    # Wrapper with file-input controller
    assert_html(form, "div.form-group[data-controller='file-input']")
    assert_includes(form, "Upload Image")

    # File input with accept attribute (default: image/*)
    assert_html(form, "input[type='file']")
    assert_html(form, "input[accept='image/*']")

    # Validation data attributes
    assert_includes(form, "file-input#validate")
    assert_includes(form, "data-file-input-target")
    assert_includes(form, "data-max-upload-size")

    # Filename display span
    assert_html(form, "span[data-file-input-target='name']")
  end

  def test_file_field_with_multiple
    form = render_form do
      file_field(:images, label: "Upload Images", multiple: true)
    end

    assert_html(form, "input[type='file'][multiple]")
    assert_html(form, "input[accept='image/*']")
  end

  def test_file_field_with_custom_controller
    form = render_form do
      file_field(:images,
                 label: "Images",
                 controller: "form-images",
                 action: "change->form-images#addSelectedFiles")
    end

    # Should NOT have file-input controller on wrapper
    assert_no_html(form, "[data-controller='file-input']")

    # Should have custom action
    assert_includes(form, "change->form-images#addSelectedFiles")

    # Should NOT render filename display (that's for file-input controller)
    assert_not_includes(form, "data-file-input-target=\"name\"")
  end

  def test_file_field_with_custom_accept
    form = render_form do
      file_field(:document, label: "Upload PDF", accept: "application/pdf")
    end

    assert_html(form, "input[accept='application/pdf']")
  end

  def test_file_field_with_custom_button_text
    form = render_form do
      file_field(:image, label: "Image", button_text: "Choose file...")
    end

    assert_includes(form, "Choose file...")
  end
end
