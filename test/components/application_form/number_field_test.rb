# frozen_string_literal: true

require "test_helper"

# Tests for the `number_field` ApplicationForm helper.
class NumberFieldTest < ComponentTestCase
  include ApplicationFormFieldTestHelpers

  def setup
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)
  end

  # Number field tests
  def test_number_field_renders_with_basic_options
    form = render_form do
      number_field(:count, label: "Count")
    end

    assert_includes(form, "form-group")
    assert_includes(form, "Count")
    assert_includes(form, "form-control")
    assert_includes(form, 'type="number"')
  end

  # Regression: Phlex number_field defaults `min: 1`. Matches ERB
  # number_field_with_label's `opts[:min] ||= 1`.
  def test_number_field_defaults_min_to_1
    form = render_form do
      number_field(:count, label: "Count")
    end

    assert_html(form, "input[type='number'][min='1']")
  end

  # Regression: explicit `min:` override is respected.
  def test_number_field_explicit_min_overrides_default
    form = render_form do
      number_field(:count, label: "Count", min: 0)
    end

    assert_html(form, "input[type='number'][min='0']")
  end
end
