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

  # Regression: label `for=` must match the id Rails' `radio_button`
  # generates. Rails' internal `sanitized_value` lowercases the value,
  # replaces whitespace with underscores, and strips other non-word
  # chars; values like "Hello World" or symbols with special chars
  # would otherwise produce a `for=` that doesn't match the input id.
  def test_radio_with_label_for_attr_matches_sanitized_radio_button_id
    form = ActionView::Helpers::FormBuilder.new(
      :widget, nil, self, {}
    )

    # Mixed-case value with whitespace — exercises the sanitization
    html = radio_with_label(
      form: form, field: :flavor, value: "Hello World", label: "Pick one"
    )

    # Rails sanitizes "Hello World" → "hello_world" for the input id;
    # our label `for=` uses `parameterize(separator: "_")` to match.
    assert_match(/type="radio"[^>]+id="widget_flavor_hello_world"/, html,
                 "Radio input id should be Rails-sanitized form of value")
    assert_match(/<label[^>]+for="widget_flavor_hello_world"/, html,
                 "Label `for=` must match the radio input's sanitized id")
  end

  # Simpler symbol-value case — the common pattern in MO callers
  # (e.g. :txt, :rtf, :csv from species_lists/downloads).
  def test_radio_with_label_for_attr_with_symbol_value
    form = ActionView::Helpers::FormBuilder.new(
      :report, nil, self, {}
    )

    html = radio_with_label(
      form: form, field: :type, value: :txt, label: "Plain Text"
    )

    assert_match(/type="radio"[^>]+id="report_type_txt"/, html)
    assert_match(/<label[^>]+for="report_type_txt"/, html)
  end
end
