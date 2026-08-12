# frozen_string_literal: true

require "test_helper"

# Tests for the `submit` ApplicationForm helper.
class SubmitTest < ComponentTestCase
  include ApplicationFormFieldTestHelpers

  def setup
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)
  end

  # Submit button tests
  def test_submit_with_center_option
    form = render_form do
      submit("Save", center: true)
    end

    assert_html(form, "button[type='submit'].center-block")
    assert_includes(form, "my-3")
  end

  # `as:` other than :button delegates to Superform's submit, which renders an
  # <input type="submit"> rather than MO's Button::Submit <button>.
  def test_submit_as_non_button_uses_superform_input
    form = render_form do
      submit("Save", as: :input)
    end

    assert_html(form, "input[type='submit'][value='Save']")
  end

  def test_submit_with_custom_submits_with
    form = render_form do
      submit("Save", submits_with: "Saving...")
    end

    assert_html(form,
                "button[type='submit'][data-turbo-submits-with='Saving...']")
  end

  # Mirrors ERB `forms_helper.rb#submits_default_text`: an Update
  # button shows "Updating" in-flight, anything else shows "Submitting".
  def test_submit_default_submits_with_for_update_button
    form = render_form { submit(:update.ti) }

    submits_with = "data-turbo-submits-with='#{:updating.ti}'"
    assert_html(form, "button[type='submit'][#{submits_with}]")
  end

  def test_submit_default_submits_with_for_create_button
    form = render_form { submit(:create.ti) }

    submits_with = "data-turbo-submits-with='#{:submitting.ti}'"
    assert_html(form, "button[type='submit'][#{submits_with}]")
  end

  def test_submit_with_custom_data_attributes
    form = render_form do
      submit("Save", data: { confirm: "Are you sure?" })
    end

    assert_html(form, "button[type='submit'][data-confirm='Are you sure?']")
  end

  # `as: :input` falls through to SuperForm's default submit input.
  def test_submit_as_input_renders_input_element
    form = render_form { submit("Save", as: :input) }

    assert_html(form, "input[type='submit'][value='Save']")
  end
end
