# frozen_string_literal: true

require "test_helper"

# Tests for the `read_only_field` ApplicationForm helper.
class ReadOnlyFieldTest < ComponentTestCase
  include ApplicationFormFieldTestHelpers

  def setup
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)
  end

  # Regression: ReadOnlyField label should carry `for=` pointing at the
  # hidden input's id, matching the ERB `form.label(field, ...)` output.
  def test_read_only_field_label_has_for_attribute
    form = render_form do
      read_only_field(:number, label: "Number:", value: "42")
    end

    assert_html(form, "label[for='collection_number_number']")
    assert_html(form, "input[type='hidden'][id='collection_number_number']")
  end
end
