# frozen_string_literal: true

require("test_helper")

# Test form helpers
class FormsHelperTest < ActionView::TestCase
  def test_file_field_with_label_has_accept_attribute
    # Create a minimal form builder for testing
    form = ActionView::Helpers::FormBuilder.new(
      :upload, nil, self, {}
    )

    html = file_field_with_label(
      form: form,
      field: :image,
      label: "Upload Image"
    )

    # Should have accept="image/*" attribute to restrict file picker to images
    assert_includes(html, 'accept="image/*"',
                    "File input should have accept attribute for images")
  end

  def test_file_field_with_label_has_file_input_controller
    form = ActionView::Helpers::FormBuilder.new(
      :upload, nil, self, {}
    )

    html = file_field_with_label(
      form: form,
      field: :image,
      label: "Upload Image"
    )

    # Should have Stimulus controller for client-side validation
    assert_includes(html, 'data-controller="file-input"',
                    "Should have file-input Stimulus controller")
    # HTML escapes > to &gt; in attributes
    assert_includes(html, "change-&gt;file-input#validate",
                    "Should trigger validation on change")
  end
end
