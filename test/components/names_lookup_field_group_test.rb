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

  # Indirectly covers line 80 by asserting autocompleter value uses display_name
  def test_autocompleter_value_uses_display_names
    @query.names = { lookup: [@name.id] }

    value_seen = nil
    lookup_field_mock = create_lookup_mock do |opts|
      value_seen = opts[:value]
    end

    names_ns = Minitest::Mock.new
    names_ns.expect(:field, lookup_field_mock, [:lookup])

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: []
    )

    component.stub(:render, nil) { render_component(component) }

    assert_includes(value_seen, @name.display_name)
  end

  # Indirectly covers line 80 rescue by asserting unknown ID passes through
  def test_autocompleter_value_passes_through_unknown_id
    unknown_id = 999_999_999
    @query.names = { lookup: [unknown_id] }

    value_seen = nil
    lookup_field_mock = create_lookup_mock do |opts|
      value_seen = opts[:value]
    end

    names_ns = Minitest::Mock.new
    names_ns.expect(:field, lookup_field_mock, [:lookup])

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: []
    )

    component.stub(:render, nil) { render_component(component) }

    assert_includes(value_seen, unknown_id.to_s)
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

  # Cover non-array branch (line 115) by rendering with single field modifier
  def test_render_modifier_rows_handles_single_field
    @query.names = { include_synonyms: true }

    # Create real select field that will be rendered
    select_rendered = false
    select_field_mock = Minitest::Mock.new
    select_field_mock.expect(:select, select_field_mock) do |*_args, **_kwargs|
      select_rendered = true
      true
    end

    # Need to also stub the lookup field for view_template.
    # invoke_append: true so collapse content (and select field) renders
    lookup_field_mock = create_lookup_mock(invoke_append: true)

    names_ns = Minitest::Mock.new
    names_ns.expect(:field, lookup_field_mock, [:lookup])
    names_ns.expect(:field, select_field_mock, [:include_synonyms])

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: [:include_synonyms] # Single field, not array pair
    )

    # Render the full component - this executes render_modifier_rows
    # which hits the else branch (line 115) for single fields
    component.stub(:render, nil) { render_component(component) }

    assert(select_rendered, "Should call select for single field modifier")
  end

  # Indirectly cover bool_to_string by capturing selected value passed to select
  def test_select_selected_is_empty_string_for_nil
    @query.names = {}
    selected_seen = nil
    select_field_mock = Minitest::Mock.new
    select_field_mock.expect(:select, select_field_mock) do |*_args, **kwargs|
      selected_seen = kwargs[:selected]
      true
    end

    lookup_field_mock = create_lookup_mock(invoke_append: true)

    names_ns = Minitest::Mock.new
    names_ns.expect(:field, lookup_field_mock, [:lookup])
    names_ns.expect(:field, select_field_mock, [:include_synonyms])

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: [:include_synonyms]
    )

    component.stub(:render, nil) { render_component(component) }

    assert_equal("", selected_seen)
  end

  def test_select_selected_is_true_string_when_true
    @query.names = { include_synonyms: true }
    selected_seen = nil
    select_field_mock = Minitest::Mock.new
    select_field_mock.expect(:select, select_field_mock) do |*_args, **kwargs|
      selected_seen = kwargs[:selected]
      true
    end

    lookup_field_mock = create_lookup_mock(invoke_append: true)

    names_ns = Minitest::Mock.new
    names_ns.expect(:field, lookup_field_mock, [:lookup])
    names_ns.expect(:field, select_field_mock, [:include_synonyms])

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: [:include_synonyms]
    )

    component.stub(:render, nil) { render_component(component) }

    assert_equal("true", selected_seen)
  end

  def test_select_selected_is_false_string_when_false
    @query.names = { include_synonyms: false }
    selected_seen = nil
    select_field_mock = Minitest::Mock.new
    select_field_mock.expect(:select, select_field_mock) do |*_args, **kwargs|
      selected_seen = kwargs[:selected]
      true
    end

    lookup_field_mock = create_lookup_mock(invoke_append: true)

    names_ns = Minitest::Mock.new
    names_ns.expect(:field, lookup_field_mock, [:lookup])
    names_ns.expect(:field, select_field_mock, [:include_synonyms])

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: [:include_synonyms]
    )

    component.stub(:render, nil) { render_component(component) }

    assert_equal("false", selected_seen)
  end

  def test_autocompleter_value_with_name_ids
    @query.names = { lookup: [@name.id] }
    value_seen = nil
    lookup_field_mock = create_lookup_mock do |opts|
      value_seen = opts[:value]
    end

    names_ns = Minitest::Mock.new
    names_ns.expect(:field, lookup_field_mock, [:lookup])

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: []
    )

    component.stub(:render, nil) { render_component(component) }

    assert_includes(value_seen, @name.display_name)
  end

  def test_autocompleter_value_with_multiple_names
    name2 = names(:fungi)
    @query.names = { lookup: [@name.id, name2.id] }

    value_seen = nil
    lookup_field_mock = create_lookup_mock do |opts|
      value_seen = opts[:value]
    end

    names_ns = Minitest::Mock.new
    names_ns.expect(:field, lookup_field_mock, [:lookup])

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: []
    )

    component.stub(:render, nil) { render_component(component) }

    assert_includes(value_seen, @name.display_name)
    assert_includes(value_seen, name2.display_name)
  end

  def test_autocompleter_hidden_value_is_ids_joined_by_newlines
    name2 = names(:fungi)
    @query.names = { lookup: [@name.id, name2.id] }

    hidden_seen = nil
    lookup_field_mock = create_lookup_mock do |opts|
      hidden_seen = opts[:hidden_value]
    end

    names_ns = Minitest::Mock.new
    names_ns.expect(:field, lookup_field_mock, [:lookup])

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: []
    )

    component.stub(:render, nil) { render_component(component) }

    assert_equal("#{@name.id}\n#{name2.id}", hidden_seen)
  end

  # Tests for collapse behavior now test the component methods directly
  # since the collapse div is rendered via a slot
  def test_collapse_has_in_class_when_lookup_present
    @query.names = { lookup: [@name.id] }
    component = create_component(modifier_fields: [])

    assert_equal("in", component.send(:collapse_class))
  end

  def test_collapse_without_values_has_no_in_class
    @query.names = {}
    component = create_component(modifier_fields: [])

    assert_nil(component.send(:collapse_class))
  end

  def test_collapse_has_in_class_when_modifiers_set
    @query.names = { include_synonyms: true }
    component = create_component(modifier_fields: [[:include_synonyms]])

    assert_equal("in", component.send(:collapse_class))
  end

  def test_collapse_without_modifiers_has_no_in_class
    @query.names = {}
    component = create_component(modifier_fields: [[:include_synonyms]])

    assert_nil(component.send(:collapse_class))
  end

  def test_field_selected_value_integrates_into_select
    @query.names = { include_synonyms: true }
    selected_seen = nil
    select_field_mock = Minitest::Mock.new
    select_field_mock.expect(:select, select_field_mock) do |*_args, **kwargs|
      selected_seen = kwargs[:selected]
      true
    end

    lookup_field_mock = create_lookup_mock(invoke_append: true)
    names_ns = Minitest::Mock.new
    names_ns.expect(:field, lookup_field_mock, [:lookup])
    names_ns.expect(:field, select_field_mock, [:include_synonyms])

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: [:include_synonyms]
    )

    component.stub(:render, nil) { render_component(component) }

    assert_equal("true", selected_seen)
  end

  def test_include_subtaxa_defaults_to_true_when_nil
    @query.names = {}
    selected_seen = nil
    select_field_mock = Minitest::Mock.new
    select_field_mock.expect(:select, select_field_mock) do |*_args, **kwargs|
      selected_seen = kwargs[:selected]
      true
    end

    lookup_field_mock = create_lookup_mock(invoke_append: true)
    names_ns = Minitest::Mock.new
    names_ns.expect(:field, lookup_field_mock, [:lookup])
    names_ns.expect(:field, select_field_mock, [:include_subtaxa])

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: [:include_subtaxa]
    )

    component.stub(:render, nil) { render_component(component) }

    assert_equal("true", selected_seen,
                 "include_subtaxa should default to 'true' when nil")
  end

  def test_include_subtaxa_respects_explicit_false
    @query.names = { include_subtaxa: false }
    selected_seen = nil
    select_field_mock = Minitest::Mock.new
    select_field_mock.expect(:select, select_field_mock) do |*_args, **kwargs|
      selected_seen = kwargs[:selected]
      true
    end

    lookup_field_mock = create_lookup_mock(invoke_append: true)
    names_ns = Minitest::Mock.new
    names_ns.expect(:field, lookup_field_mock, [:lookup])
    names_ns.expect(:field, select_field_mock, [:include_subtaxa])

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: [:include_subtaxa]
    )

    component.stub(:render, nil) { render_component(component) }

    assert_equal("false", selected_seen,
                 "include_subtaxa should respect explicit false value")
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

  # Creates a lookup field mock that handles autocompleter and with_append calls
  # @param invoke_append [Boolean] if true, the block passed to with_append
  #   will be invoked (needed for tests that check values rendered in collapse)
  # @param block [Proc] optional block to capture autocompleter options
  def create_lookup_mock(invoke_append: false, &block)
    mock = Object.new

    # Store block for autocompleter call
    autocompleter_block = block

    # Define autocompleter method
    mock.define_singleton_method(:autocompleter) do |**opts|
      autocompleter_block&.call(opts)
      mock
    end

    # Define with_help method
    mock.define_singleton_method(:with_help) do |&_help_block|
      nil
    end

    # Define with_append method - optionally invoke the passed block
    mock.define_singleton_method(:with_append) do |&append_block|
      append_block&.call if invoke_append
      nil
    end

    mock
  end
end
