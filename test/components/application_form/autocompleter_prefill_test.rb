# frozen_string_literal: true

require "test_helper"
require "ostruct"

class ApplicationFormAutocompleterPrefillTest < UnitTestCase
  include ComponentTestHelper

  # Test form that includes the AutocompleterPrefill module
  class TestForm < Components::ApplicationForm
    include Components::ApplicationForm::AutocompleterPrefill
  end

  def setup
    super
    # Use an actual ActiveRecord model
    @model = User.new
    @form = TestForm.new(@model)
    @user = users(:rolf)
    @name = names(:coprinus_comatus)
    @location = locations(:albion)
    @project = projects(:bolete_project)
  end

  # Test autocompleter_type method - line 18-31
  def test_autocompleter_type_for_project_lists
    assert_equal(:project, @form.autocompleter_type(:project_lists))
  end

  def test_autocompleter_type_for_lookup
    assert_equal(:name, @form.autocompleter_type(:lookup))
  end

  def test_autocompleter_type_for_by_users
    assert_equal(:user, @form.autocompleter_type(:by_users))
  end

  def test_autocompleter_type_for_by_editor
    assert_equal(:user, @form.autocompleter_type(:by_editor))
  end

  def test_autocompleter_type_for_members
    assert_equal(:user, @form.autocompleter_type(:members))
  end

  def test_autocompleter_type_for_within_locations
    assert_equal(:location, @form.autocompleter_type(:within_locations))
  end

  def test_autocompleter_type_defaults_to_singularized_field_name
    assert_equal(:location, @form.autocompleter_type(:locations))
    assert_equal(:name, @form.autocompleter_type(:names))
  end

  # Test prefilled_autocompleter_value method - line 35-39
  def test_prefilled_autocompleter_value_returns_non_array_values_unchanged
    assert_equal("test", @form.prefilled_autocompleter_value("test", :user))
    assert_equal(123, @form.prefilled_autocompleter_value(123, :user))
    assert_nil(@form.prefilled_autocompleter_value(nil, :user))
  end

  def test_prefilled_autocompleter_value_processes_array_values
    result = @form.prefilled_autocompleter_value([@user.id], :user)
    assert_equal(@user.unique_text_name, result)
  end

  # Test numeric_value? method - line 54-56
  def test_numeric_value_recognizes_numeric
    assert(@form.send(:numeric_value?, 123))
    assert(@form.send(:numeric_value?, 123.45))
  end

  def test_numeric_value_recognizes_numeric_strings
    assert(@form.send(:numeric_value?, "123"))
    assert(@form.send(:numeric_value?, "123.45"))
    assert(@form.send(:numeric_value?, "-123"))
    assert(@form.send(:numeric_value?, ".45"))
  end

  def test_numeric_value_rejects_non_numeric_strings
    assert_not(@form.send(:numeric_value?, "abc"))
    assert_not(@form.send(:numeric_value?, "12a3"))
  end

  # Test prefill_via_id method - line 58-67
  def test_prefill_via_id_for_user
    result = @form.send(:prefill_via_id, @user.id, :user)
    assert_equal(@user.unique_text_name, result)
  end

  def test_prefill_via_id_for_name
    result = @form.send(:prefill_via_id, @name.id, :name)
    assert_equal(@name.text_name, result)
  end

  def test_prefill_via_id_for_location
    result = @form.send(:prefill_via_id, @location.id, :location)
    assert_equal(@location.name, result)
  end

  def test_prefill_via_id_for_project
    result = @form.send(:prefill_via_id, @project.id, :project)
    assert_equal(@project.title, result)
  end

  def test_prefill_via_id_returns_original_value_when_record_not_found
    result = @form.send(:prefill_via_id, 999_999_999, :user)
    assert_equal(999_999_999, result)
  end

  # Test prefill_string_values method - line 43-51
  def test_prefill_string_values_with_mixed_ids_and_strings
    result = @form.send(
      :prefill_string_values,
      [@user.id, "existing text", @name.id],
      :user
    )
    expected = [
      @user.unique_text_name,
      "existing text",
      # Name ID treated as user lookup will fail, so returns original
      @name.id.to_s
    ].join("\n")
    assert_equal(expected, result)
  end

  def test_prefill_string_values_joins_with_newlines
    result = @form.send(:prefill_string_values, [@user.id, @user.id], :user)
    assert_includes(result, "\n")
    assert_equal(2, result.split("\n").length)
  end

  # Integration test covering full flow
  def test_full_prefill_flow_with_array_of_ids
    result = @form.prefilled_autocompleter_value(
      [@user.id, users(:mary).id],
      :user
    )
    assert_includes(result, @user.unique_text_name)
    assert_includes(result, users(:mary).unique_text_name)
    assert_includes(result, "\n")
  end
end
