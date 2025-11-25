# frozen_string_literal: true

require("test_helper")

class SearchFieldUITest < UnitTestCase
  # Mock controller for Observations search
  class MockObservationsController
    def self.name
      "Observations::SearchController"
    end

    def permitted_search_params
      [
        :date,
        :has_name,
        :by_users,
        :names,
        :confidence,
        :region,
        :in_box,
        :has_comments,
        :include_synonyms,
        :field_slips,
        :undefined_field
      ]
    end

    def nested_names_params
      [:include_synonyms, :include_subtaxa]
    end
  end

  # Mock controller for Names search
  class MockNamesController
    def self.name
      "Names::SearchController"
    end

    def permitted_search_params
      [:names, :region]
    end

    def nested_names_params
      [:include_synonyms]
    end
  end

  # Mock controller for Locations search
  class MockLocationsController
    def self.name
      "Locations::SearchController"
    end

    def permitted_search_params
      [:region, :in_box]
    end

    def nested_names_params
      []
    end
  end

  def setup
    @obs_controller = MockObservationsController.new
    @names_controller = MockNamesController.new
    @locations_controller = MockLocationsController.new
  end

  # Test class method .for
  def test_class_method_for
    result = SearchFieldUI.for(
      controller: @obs_controller,
      field: :has_name
    )
    assert_equal(:select_nil_boolean, result)
  end

  # Test special case: names field for observations
  def test_names_field_for_observations
    ui = SearchFieldUI.new(controller: @obs_controller, field: :names)
    assert_equal(:names_fields_for_obs, ui.ui_type)
  end

  # Test special case: names field for names controller
  def test_names_field_for_names
    ui = SearchFieldUI.new(controller: @names_controller, field: :names)
    assert_equal(:names_fields_for_names, ui.ui_type)
  end

  # Test special case: region field for observations (with in_box)
  def test_region_field_for_observations
    ui = SearchFieldUI.new(controller: @obs_controller, field: :region)
    assert_equal(:region_with_in_box_fields, ui.ui_type)
  end

  # Test special case: region field for locations (with in_box)
  def test_region_field_for_locations
    ui = SearchFieldUI.new(controller: @locations_controller, field: :region)
    assert_equal(:region_with_in_box_fields, ui.ui_type)
  end

  # Test special case: region field for names (text field)
  def test_region_field_for_names
    ui = SearchFieldUI.new(controller: @names_controller, field: :region)
    assert_equal(:text_field_with_label, ui.ui_type)
  end

  # Test special case: in_box field
  def test_in_box_field
    ui = SearchFieldUI.new(controller: @obs_controller, field: :in_box)
    assert_equal(:in_box_fields, ui.ui_type)
  end

  # Test special case: field_slips
  def test_field_slips
    ui = SearchFieldUI.new(controller: @obs_controller, field: :field_slips)
    assert_equal(:text_field_with_label, ui.ui_type)
  end

  # Test custom select UI: include_synonyms
  def test_include_synonyms
    ui = SearchFieldUI.new(
      controller: @obs_controller,
      field: :include_synonyms
    )
    assert_equal(:select_no_eq_nil_or_yes, ui.ui_type)
  end

  # Test custom select UI: confidence
  def test_confidence_range
    ui = SearchFieldUI.new(controller: @obs_controller, field: :confidence)
    assert_equal(:select_confidence_range, ui.ui_type)
  end

  # Test boolean field
  def test_boolean_field
    ui = SearchFieldUI.new(controller: @obs_controller, field: :has_name)
    assert_equal(:select_nil_boolean, ui.ui_type)
  end

  # Test array of User (Class) field
  def test_array_of_class_field
    ui = SearchFieldUI.new(controller: @obs_controller, field: :by_users)
    assert_equal(:multiple_value_autocompleter, ui.ui_type)
  end

  # Test array of date field
  def test_array_of_date_field
    ui = SearchFieldUI.new(controller: @obs_controller, field: :date)
    assert_equal(:text_field_with_label, ui.ui_type)
  end

  # Test hash with boolean field
  def test_hash_with_boolean_field
    ui = SearchFieldUI.new(controller: @obs_controller, field: :has_comments)
    assert_equal(:select_nil_yes, ui.ui_type)
  end

  # Test error when field is not permitted
  def test_raises_error_for_unpermitted_field
    error = assert_raises(RuntimeError) do
      SearchFieldUI.new(
        controller: @obs_controller,
        field: :invalid_field
      ).ui_type
    end
    assert_match(/Search field not permitted: invalid_field/, error.message)
    assert_match(/Observations::SearchController/, error.message)
  end

  # Test nested params are included in permitted fields
  def test_nested_params_are_permitted
    # include_synonyms is in nested_names_params, should not raise error
    ui = SearchFieldUI.new(
      controller: @obs_controller,
      field: :include_synonyms
    )
    assert_equal(:select_no_eq_nil_or_yes, ui.ui_type)
  end

  # Test error for unhandled query attribute definition
  def test_raises_error_for_unhandled_definition
    # Create a mock attribute that returns :undefined type
    mock_attribute = Minitest::Mock.new
    mock_attribute.expect(:accepts, :undefined)

    # Stub attribute_types to return our mock for :undefined_field
    Query::Observations.stub(:attribute_types, {
                               undefined_field: mock_attribute
                             }) do
      error = assert_raises(RuntimeError) do
        SearchFieldUI.new(
          controller: @obs_controller,
          field: :undefined_field
        ).ui_type
      end
      assert_match(
        /Unhandled query attribute definition \(SearchFieldUI\)/,
        error.message
      )
      assert_match(/undefined_field/, error.message)
      assert_match(/:undefined/, error.message)
    end

    mock_attribute.verify
  end
end
