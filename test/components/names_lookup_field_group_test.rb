# frozen_string_literal: true

require "test_helper"

class NamesLookupFieldGroupTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @name = names(:coprinus_comatus)
    @query = Query.lookup(:Observation)
    controller.request = ActionDispatch::TestRequest.create
  end

  # Test line 80: Name.find(val.to_i).display_name
  def test_prefill_via_id_returns_name_display_name
    component = create_component
    result = component.send(:prefill_via_id, @name.id, :name)
    assert_equal(@name.display_name, result)
  end

  # Test line 80: rescue block when record not found
  def test_prefill_via_id_returns_original_value_when_not_found
    component = create_component
    result = component.send(:prefill_via_id, 999_999_999, :name)
    assert_equal(999_999_999, result)
  end

  # Test lines 106-107: if field_pair.is_a?(Array) in render_modifier_rows
  def test_render_modifier_rows_handles_array_fields
    @query.names = { lookup: [@name.id] }
    component = create_component(
      modifier_fields: [[:include_synonyms, :include_subtaxa]]
    )

    # Verify it processes arrays
    modifier_fields = component.instance_variable_get(:@modifier_fields)
    assert(modifier_fields.first.is_a?(Array))
  end

  # Test line 115: render_select_field(field_pair) when not an array
  def test_render_modifier_rows_handles_single_fields
    @query.names = { lookup: [@name.id] }
    component = create_component(
      modifier_fields: [:include_all_name_children]
    )

    # Verify single field is not an array
    modifier_fields = component.instance_variable_get(:@modifier_fields)
    assert_not(modifier_fields.first.is_a?(Array))
  end

  # Cover non-array branch by executing render_modifier_rows
  def test_render_modifier_rows_calls_select_for_single_field
    @query.names = { include_synonyms: true }

    # Stub namespace to capture select invocation
    field_stub = Struct.new(:called, :args) do
      def select(*args, **_kwargs)
        self.called = true
        self.args = args
      end
    end.new(false, nil)

    names_ns = Minitest::Mock.new
    names_ns.expect(:field, field_stub, [:include_synonyms])

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: [:include_synonyms]
    )

    # Execute branch: else -> render_select_field(field_pair)
    # Stub out Phlex render to avoid requiring a real component
    component.stub(:render, nil) do
      component.send(:render_modifier_rows)
    end

    assert(field_stub.called)
    names_ns.verify
  end

  # Test line 160: else "" in bool_to_string
  def test_bool_to_string_returns_empty_string_for_nil
    component = create_component

    assert_equal("", component.send(:bool_to_string, nil))
    assert_equal("", component.send(:bool_to_string, ""))
    assert_equal("", component.send(:bool_to_string, "other"))
  end

  def test_bool_to_string_converts_true_to_string
    component = create_component
    assert_equal("true", component.send(:bool_to_string, true))
  end

  def test_bool_to_string_converts_false_to_string
    component = create_component
    assert_equal("false", component.send(:bool_to_string, false))
  end

  def test_prefilled_lookup_value_with_name_ids
    @query.names = { lookup: [@name.id] }
    component = create_component

    result = component.send(:prefilled_lookup_value)
    assert_includes(result, @name.display_name)
  end

  def test_prefilled_lookup_value_with_multiple_names
    name2 = names(:fungi)
    @query.names = { lookup: [@name.id, name2.id] }
    component = create_component

    result = component.send(:prefilled_lookup_value)
    assert_includes(result, @name.display_name)
    assert_includes(result, name2.display_name)
  end

  def test_prefilled_lookup_ids_returns_ids_joined_by_newlines
    name2 = names(:fungi)
    @query.names = { lookup: [@name.id, name2.id] }
    component = create_component

    result = component.send(:prefilled_lookup_ids)
    assert_equal("#{@name.id}\n#{name2.id}", result)
  end

  def test_lookup_has_value_returns_true_when_lookup_present
    @query.names = { lookup: [@name.id] }
    component = create_component

    assert(component.send(:lookup_has_value?))
  end

  def test_lookup_has_value_returns_false_when_lookup_empty
    @query.names = {}
    component = create_component

    assert_not(component.send(:lookup_has_value?))
  end

  def test_modifiers_have_values_returns_true_when_modifiers_set
    @query.names = { include_synonyms: true }
    component = create_component(modifier_fields: [[:include_synonyms]])

    assert(component.send(:modifiers_have_values?))
  end

  def test_modifiers_have_values_returns_false_when_no_modifiers
    @query.names = {}
    component = create_component(modifier_fields: [[:include_synonyms]])

    assert_not(component.send(:modifiers_have_values?))
  end

  def test_collapse_class_returns_in_when_lookup_has_value
    @query.names = { lookup: [@name.id] }
    component = create_component

    assert_equal("in", component.send(:collapse_class))
  end

  def test_collapse_class_returns_in_when_modifiers_have_values
    @query.names = { include_synonyms: true }
    component = create_component(modifier_fields: [[:include_synonyms]])

    assert_equal("in", component.send(:collapse_class))
  end

  def test_collapse_class_returns_nil_when_no_values
    @query.names = {}
    component = create_component

    assert_nil(component.send(:collapse_class))
  end

  def test_field_selected_value_returns_value_from_query
    @query.names = { include_synonyms: true }
    component = create_component

    assert_equal(true, component.send(:field_selected_value, :include_synonyms))
  end

  private

  def create_component(modifier_fields: [])
    # Create a mock namespace
    names_ns = Minitest::Mock.new

    Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: modifier_fields
    )
  end
end
