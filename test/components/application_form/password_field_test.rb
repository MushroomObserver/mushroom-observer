# frozen_string_literal: true

require "test_helper"

# Tests for the `password_field` ApplicationForm helper.
class PasswordFieldTest < ComponentTestCase
  include ApplicationFormFieldTestHelpers

  def setup
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)
  end

  # Password field tests
  def test_password_field_renders_with_basic_options
    form = render_form do
      password_field(:password, label: "Password")
    end

    assert_includes(form, "form-group")
    assert_includes(form, "Password")
    assert_includes(form, "form-control")
    assert_includes(form, 'type="password"')
  end

  # Regression: Phlex password_field defaults `value: ""` to prevent
  # Rails from re-populating the field with the stored password hash
  # on form re-render. Matches ERB password_field_with_label.
  def test_password_field_defaults_value_to_empty_string
    form = render_form do
      password_field(:password, label: "Password")
    end

    assert_html(form, "input[type='password'][value='']")
  end

  # Regression: explicit `value:` override is respected.
  def test_password_field_explicit_value_overrides_default
    form = render_form do
      password_field(:password, label: "Password", value: "stored-hash")
    end

    assert_html(form, "input[type='password'][value='stored-hash']")
  end
end
