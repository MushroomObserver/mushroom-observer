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

  # Regression: number_field_with_label uses the flex `text_label_row`
  # so a help-button / between / label_end ride next to the label,
  # matching `text_field_with_label`.
  def test_number_field_with_label_uses_label_row
    form = ActionView::Helpers::FormBuilder.new(
      :user, nil, self, {}
    )

    html = number_field_with_label(
      form: form, field: :layout_count, label: "Layout count",
      between: "(per page)"
    )

    assert_match(/<div class="d-flex justify-content-between">/, html)
    assert_match(%r{<label[^>]+>Layout count</label>}, html)
    assert_includes(html, "(per page)")
  end

  def test_number_field_with_label_defaults_min_to_1
    form = ActionView::Helpers::FormBuilder.new(
      :user, nil, self, {}
    )

    html = number_field_with_label(
      form: form, field: :layout_count, label: "Layout count"
    )

    # Attribute order is Rails-dependent; assert both attrs present on
    # the same input tag without pinning their order.
    assert_match(/<input[^>]+min="1"/, html)
    assert_match(/<input[^>]+type="number"/, html)
  end

  # Regression: password_field_with_label uses the flex `text_label_row`
  # so a help-button / between / label_end ride next to the label.
  def test_password_field_with_label_uses_label_row
    form = ActionView::Helpers::FormBuilder.new(
      :user, nil, self, {}
    )

    html = password_field_with_label(
      form: form, field: :password, label: "Password",
      between: "(at least 8 chars)"
    )

    assert_match(/<div class="d-flex justify-content-between">/, html)
    assert_match(%r{<label[^>]+>Password</label>}, html)
    assert_includes(html, "(at least 8 chars)")
  end

  def test_password_field_with_label_defaults_value_to_empty_string
    form = ActionView::Helpers::FormBuilder.new(
      :user, nil, self, {}
    )

    html = password_field_with_label(
      form: form, field: :password, label: "Password"
    )

    assert_match(/<input[^>]+value=""/, html)
    assert_match(/<input[^>]+type="password"/, html)
  end
end
