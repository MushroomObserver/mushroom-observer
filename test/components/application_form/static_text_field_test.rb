# frozen_string_literal: true

require "test_helper"

# Tests for the `static_field` ApplicationForm helper.
class StaticTextFieldTest < ComponentTestCase
  include ApplicationFormFieldTestHelpers

  def setup
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)
  end

  # Regression: StaticTextField label should carry `for=` pointing at the
  # field's dom id (even though there's no input — matches ERB output).
  def test_static_field_label_has_for_attribute
    form = render_form do
      static_field(:number, label: "Number:", value: "42")
    end

    assert_html(form, "label[for='collection_number_number']")
  end
end
